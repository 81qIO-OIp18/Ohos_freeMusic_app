import { media } from '@kit.MediaKit'
import { promptAction } from '@kit.ArkUI'
import { common, wantAgent } from '@kit.AbilityKit'
import { avSession } from '@kit.AVSessionKit'
import { image } from '@kit.ImageKit'
import { http } from '@kit.NetworkKit'
import { SongItem, SongDetail } from '../viewmodles/commons'
import { MUSIC_free_list_API, MUSIC_free_API } from '../apis'
import { parseLrc, findLrcIndex, fmtMs, LrcLine } from '../utils/LrcUtils'
import { BackgroundUtil } from '../utils/BackgroundUtil'

/**
 * 免费音乐首页（搜索 + 播放）
 */
@Component
export struct MusicHome {
  onSwitchPlatform: () => void = () => {
  }
  @State searchKeyword: string = ''
  @State searchResults: SongItem[] = []
  @State isSearching: boolean = false
  @State isLoading: boolean = false
  // 当前播放
  @State currentSong: SongDetail | null = null
  @State isPlaying: boolean = false
  @State currentTime: number = 0 // 秒
  @State duration: number = 0 // 秒
  @State playlist: SongItem[] = [] // 当前播放列表（搜索结果）
  @State currentIndex: number = -1 // 当前播放歌曲在列表中的索引
  @State lrcLines: LrcLine[] = [] // 解析后的歌词
  @State lrcIndex: number = -1 // 当前歌词行索引
  @State showFullPlayer: boolean = false // 是否展开全屏播放器
  @State isSeeking: boolean = false // 是否正在拖动进度条
  avPlayer: media.AVPlayer | null = null
  session: avSession.AVSession | null = null

  // 搜索
  private async doSearch() {
    const kw = this.searchKeyword.trim()
    if (kw.length === 0) {
      this.searchResults = []
      this.isSearching = false
      return
    }
    this.isLoading = true
    this.isSearching = true
    try {
      const data = await MUSIC_free_list_API(kw)
      this.searchResults = data?.songs ?? []
    } catch (e) {
      console.error('search error:', JSON.stringify(e))
      promptAction.showToast({ message: '搜索失败，请重试' })
      this.searchResults = []
    } finally {
      this.isLoading = false
    }
  }

  // 退出搜索
  private exitSearch() {
    this.searchKeyword = ''
    this.searchResults = []
    this.isSearching = false
  }

  // 播放某首歌
  private async playSong(song: SongItem) {
    if (this.currentSong && this.currentSong.name === song.name && this.currentSong.singer === song.artists) {
      this.togglePlay()
      return
    }
    // 记录播放列表与索引
    const idx = this.searchResults.findIndex((s: SongItem) =>
    s.index === song.index && s.name === song.name)
    if (idx >= 0) {
      this.playlist = this.searchResults
      this.currentIndex = idx
    }
    await this.loadAndPlay(song)
  }

  // 加载详情并播放
  private async loadAndPlay(song: SongItem) {
    try {
      const detail = await MUSIC_free_API(this.searchKeyword.trim(), song.index)
      if (!detail || !detail.play_url) {
        promptAction.showToast({ message: '暂无可播放地址' })
        return
      }
      this.currentSong = detail
      this.duration = detail.duration_sec ?? 0
      this.currentTime = 0
      // 解析歌词
      this.lrcLines = detail.lyric ? parseLrc(detail.lyric) : []
      this.lrcIndex = -1
      // 创建/更新 AVSession
      await this.createSession()
      await this.updateSessionMetadata()
      await this.startPlayer(detail.play_url)
    } catch (e) {
      console.error('playSong error:', JSON.stringify(e))
      promptAction.showToast({ message: '加载歌曲失败' })
    }
  }

  // 上一首
  private playPrev() {
    if (this.playlist.length === 0 || this.currentIndex < 0) {
      return
    }
    const prev = (this.currentIndex - 1 + this.playlist.length) % this.playlist.length
    this.currentIndex = prev
    this.loadAndPlay(this.playlist[prev])
  }

  // 下一首
  private playNext() {
    if (this.playlist.length === 0 || this.currentIndex < 0) {
      return
    }
    const next = (this.currentIndex + 1) % this.playlist.length
    this.currentIndex = next
    this.loadAndPlay(this.playlist[next])
  }

  // 启动播放器
  private async startPlayer(url: string) {
    await this.releasePlayer()
    try {
      console.info('startPlayer: createAVPlayer')
      const player = await media.createAVPlayer()
      this.avPlayer = player

      // 等待状态机进入 initialized（设置 url 后异步触发），超时 15s
      let initializedResolve: () => void = () => {
      }
      let initializedReject: (err: Error) => void = () => {
      }
      const initializedPromise = new Promise<void>((resolve, reject) => {
        initializedResolve = resolve
        initializedReject = reject
      })
      const initTimer = setTimeout(() => {
        initializedReject(new Error('等待 initialized 状态超时'))
      }, 15000)

      // stateChange：跟踪播放器状态机变化
      player.on('stateChange', (state: string) => {
        console.info('AVPlayer stateChange:', state)
        if (state === 'initialized') {
          clearTimeout(initTimer)
          initializedResolve()
        } else if (state === 'playing') {
          this.isPlaying = true
          this.updateSessionPlayState(true)
          // 播放时（前台）启动后台长时任务，保证退后台后继续播放
          this.startBgTask()
        } else if (state === 'paused' || state === 'stopped') {
          this.isPlaying = false
          this.updateSessionPlayState(false)
          this.stopBgTask()
        } else if (state === 'completed') {
          // 播放完成，自动下一首
          this.isPlaying = false
          this.updateSessionPlayState(false)
          this.stopBgTask()
          this.playNext()
        }
      })
      // error：必要事件，同样需在设置资源前注册
      player.on('error', (err: BusinessError) => {
        console.error(`AVPlayer error event: code=${err.code}, message=${err.message}`)
        this.isPlaying = false
        this.stopBgTask()
        clearTimeout(initTimer)
        initializedReject(new Error(`播放器错误:${err.code}`))
      })
      // 进度与时长：AVPlayer 回调单位为毫秒
      player.on('timeUpdate', (time: number) => {
        if (!this.isSeeking) {
          this.currentTime = Math.floor(time / 1000)
        }
        // 更新歌词高亮
        if (this.lrcLines.length > 0) {
          this.lrcIndex = findLrcIndex(this.lrcLines, time)
        }
      })
      player.on('durationUpdate', (dur: number) => {
        this.duration = Math.floor(dur / 1000)
      })
      player.on('seekDone', (seekDoneTime: number) => {
        console.info('AVPlayer seek succeeded, seek time is', seekDoneTime)
      })

      // 设置资源，等待进入 initialized 后再 prepare
      player.url = url
      await initializedPromise
      await player.prepare()
      await player.play()
    } catch (e) {
      const err = e as BusinessError
      console.error(`startPlayer failed: code=${err?.code}, message=${err?.message}`)
      this.isPlaying = false
      promptAction.showToast({ message: `播放失败:${err?.code ?? err?.message ?? ''}` })
    }
  }

  // 播放/暂停切换
  private togglePlay() {
    if (!this.avPlayer) {
      return
    }
    if (this.isPlaying) {
      this.avPlayer.pause()
    } else {
      this.avPlayer.play()
    }
  }

  // 拖动进度条跳转
  private onSeek(sec: number) {
    if (!this.avPlayer || this.duration <= 0) {
      return
    }
    this.avPlayer.seek(sec * 1000)
  }

  // 启动后台长时任务（音频播放保活）
  private startBgTask() {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      BackgroundUtil.startContinuousTask(ctx)
    } catch (e) {
      console.error('startBgTask error:', JSON.stringify(e))
    }
  }

  // 停止后台长时任务
  private stopBgTask() {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      BackgroundUtil.stopContinuousTask(ctx)
    } catch (e) {
      console.error('stopBgTask error:', JSON.stringify(e))
    }
  }

  // 创建并激活 AVSession（向系统注册媒体会话，后台播放必需）
  private async createSession() {
    if (this.session) {
      return
    }
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      this.session = await avSession.createAVSession(ctx, 'MusicFreeSession', 'audio')
      await this.session.activate()
      console.info('AVSession created and activated')
      // 设置启动 Ability（点击通知栏媒体控制回到应用）
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: ctx.abilityInfo.bundleName,
          abilityName: ctx.abilityInfo.name,
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
      }
      const agent = await wantAgent.getWantAgent(wantAgentInfo)
      await this.session.setLaunchAbility(agent)
      // 注册系统媒体控制命令监听（通知栏/锁屏的播放控制按钮）
      this.setSessionCommandListeners()
    } catch (e) {
      console.error('createSession error:', JSON.stringify(e))
    }
  }

  // 注册 AVSession 控制命令监听
  private setSessionCommandListeners() {
    if (!this.session) {
      return
    }
    try {
      this.session.on('play', () => {
        if (this.avPlayer && !this.isPlaying) {
          this.avPlayer.play()
        }
      })
      this.session.on('pause', () => {
        if (this.avPlayer && this.isPlaying) {
          this.avPlayer.pause()
        }
      })
      this.session.on('playNext', () => {
        this.playNext()
      })
      this.session.on('playPrevious', () => {
        this.playPrev()
      })
    } catch (e) {
      console.error('setSessionCommandListeners error:', JSON.stringify(e))
    }
  }

  // 更新 AVSession 媒体元数据（歌名、歌手、时长、封面、歌词）
  private async updateSessionMetadata() {
    if (!this.session || !this.currentSong) {
      return
    }
    try {
      const metadata: avSession.AVMetadata = {
        assetId: this.currentSong.id ?? '',
        title: this.currentSong.name,
        artist: this.currentSong.singer,
        duration: this.duration * 1000,
      }
      // 加载网络封面图：先用 http 下载 buffer（cover_url 是 http 明文，ImageKit 直接传 url 可能失败）
      if (this.currentSong.cover_url) {
        try {
          const httpRequest = http.createHttp()
          const response = await httpRequest.request(this.currentSong.cover_url, {
            method: http.RequestMethod.GET,
            expectDataType: http.HttpDataType.ARRAY_BUFFER,
          })
          httpRequest.destroy()
          if (response.responseCode === 200 && response.result) {
            const imageSource = image.createImageSource(response.result as ArrayBuffer)
            const pixelMap = await imageSource.createPixelMap()
            metadata.mediaImage = pixelMap
          }
        } catch (imgErr) {
          console.error('load cover image error:', JSON.stringify(imgErr))
        }
      }
      // 传递歌词（部分系统媒体控制可显示）
      if (this.currentSong.lyric) {
        const metadataAny = metadata as Record<string, Object>
        metadataAny['lyrics'] = this.currentSong.lyric
      }
      this.session.setAVMetadata(metadata).catch((err: BusinessError) => {
        console.error('setAVMetadata error:', err.code, err.message)
      })
    } catch (e) {
      console.error('updateSessionMetadata error:', JSON.stringify(e))
    }
  }

  // 更新 AVSession 播放状态
  private updateSessionPlayState(isPlay: boolean) {
    if (!this.session) {
      return
    }
    try {
      const state: avSession.AVPlaybackState = {
        state: isPlay ? avSession.PlaybackState.PLAYBACK_STATE_PLAY : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
        position: {
          elapsedTime: this.currentTime * 1000,
          updateTime: new Date().getTime(),
        },
      }
      this.session.setAVPlaybackState(state).catch((err: BusinessError) => {
        console.error('setAVPlaybackState error:', err.code, err.message)
      })
    } catch (e) {
      console.error('updateSessionPlayState error:', JSON.stringify(e))
    }
  }

  // 销毁 AVSession
  private destroySession() {
    if (this.session) {
      try {
        this.session.off('play')
        this.session.off('pause')
        this.session.off('playNext')
        this.session.off('playPrevious')
        this.session.deactivate().catch(() => {})
        this.session = null
      } catch (e) {
        console.error('destroySession error:', JSON.stringify(e))
      }
    }
  }

  // 释放播放器
  private async releasePlayer() {
    if (this.avPlayer) {
      try {
        await this.avPlayer.stop()
        await this.avPlayer.release()
      } catch (e) {
        console.error('releasePlayer error:', JSON.stringify(e))
      }
      this.avPlayer = null
    }
  }

  aboutToDisappear() {
    this.releasePlayer()
    this.destroySession()
  }

  build() {
    Stack() {
      Column() {
        // 顶部栏
        Row() {
          Text('免费音乐')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text('切换平台')
            .fontSize(13)
            .fontColor($r('app.color.accent'))
            .onClick(() => {
              this.onSwitchPlatform()
            })
        }
        .width('100%')
        .height(48)

        // 搜索框
        Row() {
          TextInput({ placeholder: '搜索歌曲或歌手', text: this.searchKeyword })
            .layoutWeight(1)
            .fontSize(14)
            .backgroundColor(Color.Transparent)
            .margin({ left: 6 })
            .onChange((val: string) => {
              this.searchKeyword = val
            })
            .onSubmit(() => {
              this.doSearch()
            })
          if (this.isSearching) {
            Text('取消')
              .fontSize(13)
              .fontColor($r('app.color.accent'))
              .margin({ left: 8 })
              .onClick(() => {
                this.exitSearch()
              })
          }
        }
        .width('100%')
        .height(38)
        .padding({ left: 12, right: 12 })
        .borderRadius(19)
        .backgroundColor($r('app.color.card_bg'))
        .margin({ top: 4 })

        // 内容区
        if (this.isSearching) {
          this.SearchResultsView()
        } else {
          this.HomeHintView()
        }

        // 底部播放栏
        if (this.currentSong) {
          this.PlayerBarView()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))
      .padding({ left: 16, right: 16, bottom: 8 })

      // 全屏播放器
      if (this.showFullPlayer) {
        this.FullPlayerView()
      }
    }
    .width('100%')
    .height('100%')
  }

  // 搜索结果
  @Builder
  SearchResultsView() {
    Column() {
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color($r('app.color.accent'))
          Text('搜索中...')
            .fontSize(13)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.searchResults.length === 0) {
        Column() {
          Text('没有找到相关歌曲')
            .fontSize(14)
            .fontColor($r('app.color.text_tertiary'))
          Text('换个关键词试试吧')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.searchResults, (song: SongItem) => {
            ListItem() {
              Row() {
                Text(song.index.toString())
                  .fontSize(14)
                  .fontColor($r('app.color.text_tertiary'))
                  .width(28)
                Column() {
                  Text(song.name)
                    .fontSize(14)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(song.artists)
                    .fontSize(11)
                    .fontColor($r('app.color.text_tertiary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 8 })

                SymbolGlyph($r('sys.symbol.play_fill'))
                  .fontSize(18)
                  .fontColor([$r('app.color.accent')])
              }
              .width('100%')
              .padding({ top: 12, bottom: 12 })
              .onClick(() => {
                this.playSong(song)
              })
            }
          }, (song: SongItem) => `${song.index}_${song.name}`)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .divider({ strokeWidth: 0.5, color: $r('app.color.divider') })
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  // 未搜索时的引导页
  @Builder
  HomeHintView() {
    Column() {
      Column() {
        Text('搜索喜爱的歌曲')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ top: 16 })
        Text('输入歌曲名或歌手名开始搜索')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: 6 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
  }

  // 底部迷你播放栏
  @Builder
  PlayerBarView() {
    Column() {
      Row() {
        // 封面
        if (this.currentSong?.cover_url) {
          Image(this.currentSong.cover_url)
            .width(40)
            .height(40)
            .borderRadius(6)
            .objectFit(ImageFit.Cover)
        } else {
          Stack() {
            Column()
              .width('100%')
              .height('100%')
              .linearGradient({
                angle: 135,
                colors: [['#5B8DEF', 0.0], ['#34495E', 1.0]]
              })
          }
          .width(40)
          .height(40)
          .borderRadius(6)
          .clip(true)
        }

        // 歌名 + 歌手
        Column() {
          Text(this.currentSong?.name ?? '')
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.currentSong?.singer ?? '')
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 2 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 10 })
        .onClick(() => {
          this.showFullPlayer = true
        })

        // 上一首
        SymbolGlyph($r('sys.symbol.backward_end_fill'))
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
          .margin({ right: 8 })
          .onClick(() => {
            this.playPrev()
          })

        // 播放/暂停
        SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause') : $r('sys.symbol.play_fill'))
          .fontSize(28)
          .fontColor([$r('app.color.accent')])
          .onClick(() => {
            this.togglePlay()
          })

        // 下一首
        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
          .margin({ left: 8 })
          .onClick(() => {
            this.playNext()
          })
      }
      .width('100%')
      .padding({
        left: 12,
        right: 12,
        top: 8,
        bottom: 8
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .margin({ top: 8 })
  }

  // 全屏播放器
  @Builder
  FullPlayerView() {
    Column() {
      // 顶部栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(24)
          .fontColor([Color.White])
          .onClick(() => {
            this.showFullPlayer = false
          })
        Column() {
          Text(this.currentSong?.name ?? '')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.currentSong?.singer ?? '')
            .fontSize(12)
            .fontColor(Color.White)
            .opacity(0.7)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .margin({ left: 16 })
        .alignItems(HorizontalAlign.Center)

        Blank().width(24)
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 12,
        bottom: 12
      })

      // 封面
      if (this.currentSong?.cover_url) {
        Image(this.currentSong.cover_url)
          .width(240)
          .height(240)
          .borderRadius(120)
          .objectFit(ImageFit.Cover)
          .margin({ top: 24 })
      } else {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .linearGradient({
              angle: 135,
              colors: [['#5B8DEF', 0.0], ['#34495E', 1.0]]
            })
        }
        .width(240)
        .height(240)
        .borderRadius(120)
        .margin({ top: 24 })
      }

      // 歌词区域
      Column() {
        if (this.lrcLines.length === 0) {
          Text('暂无歌词')
            .fontSize(14)
            .fontColor(Color.White)
            .opacity(0.5)
        } else {
          List() {
            ForEach(this.lrcLines, (line: LrcLine, index: number) => {
              ListItem() {
                Text(line.text)
                  .fontSize(index === this.lrcIndex ? 16 : 13)
                  .fontWeight(index === this.lrcIndex ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(index === this.lrcIndex ? Color.White : Color.White)
                  .opacity(index === this.lrcIndex ? 1 : 0.4)
                  .textAlign(TextAlign.Center)
                  .width('100%')
              }
            }, (line: LrcLine, index: number) => `${index}_${line.time}`)
          }
          .width('100%')
          .height(160)
          .scrollBar(BarState.Off)
          .alignListItem(ListItemAlign.Center)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ left: 24, right: 24 })
      .margin({ top: 24 })

      // 进度条
      Column() {
        Slider({
          value: this.currentTime,
          min: 0,
          max: this.duration > 0 ? this.duration : 1,
          step: 1,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .blockColor($r('app.color.accent'))
          .selectedColor($r('app.color.accent'))
          .trackColor(Color.White)
          .opacity(0.6)
          .onChange((value: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Moving) {
              this.isSeeking = true
              this.currentTime = Math.floor(value)
            } else if (mode === SliderChangeMode.End) {
              this.isSeeking = false
              this.onSeek(Math.floor(value))
            }
          })
        Row() {
          Text(fmtMs(this.currentTime * 1000))
            .fontSize(11)
            .fontColor(Color.White)
            .opacity(0.7)
          Blank()
          Text(fmtMs(this.duration * 1000))
            .fontSize(11)
            .fontColor(Color.White)
            .opacity(0.7)
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })

      // 控制按钮
      Row() {
        SymbolGlyph($r('sys.symbol.backward_end_fill'))
          .fontSize(36)
          .fontColor([Color.White])
          .onClick(() => {
            this.playPrev()
          })
        SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause') : $r('sys.symbol.play_fill'))
          .fontSize(56)
          .fontColor([Color.White])
          .margin({ left: 48, right: 48 })
          .onClick(() => {
            this.togglePlay()
          })
        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize(36)
          .fontColor([Color.White])
          .onClick(() => {
            this.playNext()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 16, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [['#1a1a2e', 0.0], ['#16213e', 0.5], ['#0f3460', 1.0]]
    })
  }
}
