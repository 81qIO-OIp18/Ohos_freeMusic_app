import { media } from '@kit.MediaKit'
import { promptAction } from '@kit.ArkUI'
import { SongItem, SongDetail } from '../viewmodles/commons'
import { MUSIC_free_list_API, MUSIC_free_API } from '../apis'

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
  @State currentTime: number = 0
  @State duration: number = 0
  avPlayer: media.AVPlayer | null = null

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
      // 同一首歌，切换播放/暂停
      this.togglePlay()
      return
    }
    try {
      const detail = await MUSIC_free_API(this.searchKeyword.trim(), song.index)
      if (!detail || !detail.play_url) {
        promptAction.showToast({ message: '暂无可播放地址' })
        return
      }
      this.currentSong = detail
      this.duration = detail.duration_sec ?? 0
      this.currentTime = 0
      await this.startPlayer(detail.play_url)
    } catch (e) {
      console.error('playSong error:', JSON.stringify(e))
      promptAction.showToast({ message: '加载歌曲失败' })
    }
  }

  // 启动播放器
  private async startPlayer(url: string) {
    await this.releasePlayer()
    try {
      console.info('startPlayer: createAVPlayer, url=', url)
      const player = await media.createAVPlayer()
      this.avPlayer = player

      // 等待状态机进入 initialized（设置 url 后异步触发），超时 15s
      let initializedResolve: () => void = () => {}
      let initializedReject: (err: Error) => void = () => {}
      const initializedPromise = new Promise<void>((resolve, reject) => {
        initializedResolve = resolve
        initializedReject = reject
      })
      const initTimer = setTimeout(() => {
        initializedReject(new Error('等待 initialized 状态超时'))
      }, 15000)

      // stateChange：跟踪播放器状态机变化
      // 必须在 idle 状态下、设置资源(url)前注册，否则可能漏报
      player.on('stateChange', (state: string) => {
        console.info('AVPlayer stateChange:', state)
        if (state === 'initialized') {
          clearTimeout(initTimer)
          initializedResolve()
        } else if (state === 'playing') {
          this.isPlaying = true
        } else if (state === 'paused' || state === 'stopped') {
          this.isPlaying = false
        }
      })
      // error：必要事件，同样需在设置资源前注册
      player.on('error', (err: BusinessError) => {
        console.error(`AVPlayer error event: code=${err.code}, message=${err.message}`)
        this.isPlaying = false
        clearTimeout(initTimer)
        initializedReject(new Error(`播放器错误:${err.code}`))
      })
      // 进度与时长：AVPlayer 回调单位为毫秒，需转秒
      player.on('timeUpdate', (time: number) => {
        this.currentTime = Math.floor(time / 1000)
      })
      player.on('durationUpdate', (dur: number) => {
        this.duration = Math.floor(dur / 1000)
      })
      // seekDone：仅用于响应 seek() 请求完成，不代表进入播放态
      player.on('seekDone', (seekDoneTime: number) => {
        console.info('AVPlayer seek succeeded, seek time is', seekDoneTime)
      })

      // 设置资源，等待进入 initialized 后再 prepare
      player.url = url
      console.info('startPlayer: url set, waiting for initialized state')
      await initializedPromise
      console.info('startPlayer: initialized, calling prepare()')
      await player.prepare()
      console.info('startPlayer: prepare() done, calling play()')
      await player.play()
      console.info('startPlayer: play() done')
    } catch (e) {
      const err = e as BusinessError
      console.error(`startPlayer failed: code=${err?.code}, message=${err?.message}, name=${err?.name}`)
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
  }

  // 秒 -> mm:ss
  private fmtTime(s: number): string {
    const m = Math.floor(s / 60)
    const sec = s % 60
    return `${m.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`
  }

  build() {
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
        // SymbolGlyph($r('sys.symbol.search'))
        //   .fontSize(16)
        //   .fontColor([$r('app.color.text_tertiary')])
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
        // SymbolGlyph($r('sys.symbol.music_note'))
        //   .fontSize(48)
        //   .fontColor([$r('app.color.accent')])
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

  // 底部播放栏
  @Builder
  PlayerBarView() {
    Column() {
      // 进度条
      Progress({
        value: this.duration > 0 ? (this.currentTime / this.duration) * 100 : 0,
        total: 100,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(2)
        .color($r('app.color.accent'))
        .backgroundColor($r('app.color.divider'))

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
            // SymbolGlyph($r('sys.symbol.music_note'))
            //   .fontSize(20)
            //   .fontColor([Color.White])
          }
          .width(40)
          .height(40)
          .borderRadius(6)
          .clip(true)
        }

        // 歌名 + 时间
        Column() {
          Text(this.currentSong?.name ?? '')
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.fmtTime(this.currentTime)} / ${this.fmtTime(this.duration)}`)
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 10 })

        // 播放/暂停
        SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
          .fontSize(28)
          .fontColor([$r('app.color.accent')])
          .onClick(() => {
            this.togglePlay()
          })
      }
      //熊出没
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
}
