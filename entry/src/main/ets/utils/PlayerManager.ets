import { media } from '@kit.MediaKit'
import { common, wantAgent } from '@kit.AbilityKit'
import { avSession } from '@kit.AVSessionKit'
import { image } from '@kit.ImageKit'
import { http } from '@kit.NetworkKit'
import { SongItem, SongDetail } from '../viewmodles/commons'
import { MUSIC_free_API } from '../apis'
import { parseLrc, findLrcIndex, LrcLine } from './LrcUtils'
import { BackgroundUtil } from './BackgroundUtil'
import { StorageManager } from './StorageManager'

/**
 * 播放器单例：跨页面共享播放状态
 * UI 组件通过 AppStorage 读取以下状态：
 *   - pm_song: 当前歌曲 SongDetail（JSON 字符串）
 *   - pm_playing: 是否播放中
 *   - pm_time: 当前时间（秒）
 *   - pm_duration: 总时长（秒）
 *   - pm_lrc: 歌词 JSON 字符串
 *   - pm_lrcIndex: 当前歌词行索引
 */
class PlayerManager {
  private static instance: PlayerManager | null = null
  private avPlayer: media.AVPlayer | null = null
  private session: avSession.AVSession | null = null
  private context: common.UIAbilityContext | null = null

  playlist: SongItem[] = []
  currentIndex: number = -1
  currentSong: SongDetail | null = null

  private isSeeking: boolean = false

  static getInstance(): PlayerManager {
    if (!PlayerManager.instance) {
      PlayerManager.instance = new PlayerManager()
    }
    return PlayerManager.instance
  }

  setContext(ctx: common.UIAbilityContext) {
    this.context = ctx
  }

  /** 读取当前歌曲 */
  getSong(): SongDetail | null {
    return this.currentSong
  }

  /** 读取播放列表 */
  getPlaylist(): SongItem[] {
    return this.playlist
  }

  /** 读取当前索引 */
  getCurrentIndex(): number {
    return this.currentIndex
  }

  // ============ AppStorage 状态同步 ============
  private syncSong() {
    AppStorage.setOrCreate('pm_song', this.currentSong ? JSON.stringify(this.currentSong) : '')
  }
  private syncPlaying(playing: boolean) {
    AppStorage.setOrCreate('pm_playing', playing)
  }
  private syncTime(sec: number) {
    AppStorage.setOrCreate('pm_time', sec)
  }
  private syncDuration(sec: number) {
    AppStorage.setOrCreate('pm_duration', sec)
  }
  private syncLrc(lines: LrcLine[]) {
    AppStorage.setOrCreate('pm_lrc', JSON.stringify(lines))
  }
  private syncLrcIndex(idx: number) {
    AppStorage.setOrCreate('pm_lrcIndex', idx)
  }

  // ============ 播放控制 ============
  /** 播放指定列表中的某首歌 */
  async play(playlist: SongItem[], index: number) {
    this.playlist = playlist
    this.currentIndex = index
    const song = playlist[index]
    if (!song) {
      return
    }
    // 获取歌曲详情
    const detail = await MUSIC_free_API(song.name, song.index)
    this.currentSong = detail
    this.syncSong()
    this.syncDuration(detail.duration_sec ?? 0)
    this.syncTime(0)
    const lrcLines = detail.lyric ? parseLrc(detail.lyric) : []
    this.syncLrc(lrcLines)
    this.syncLrcIndex(-1)
    // 存入最近播放
    this.addRecent(song)
    // 启动播放
    await this.startPlayer(detail.play_url)
    // AVSession
    await this.createSession()
    await this.updateSessionMetadata()
  }

  /** 播放/暂停切换 */
  togglePlay() {
    if (!this.avPlayer) {
      return
    }
    if (AppStorage.get<boolean>('pm_playing')) {
      this.avPlayer.pause()
    } else {
      this.avPlayer.play()
    }
  }

  /** 上一首 */
  playPrev() {
    if (this.playlist.length === 0) {
      return
    }
    this.currentIndex = (this.currentIndex - 1 + this.playlist.length) % this.playlist.length
    this.play(this.playlist, this.currentIndex)
  }

  /** 下一首 */
  playNext() {
    if (this.playlist.length === 0) {
      return
    }
    this.currentIndex = (this.currentIndex + 1) % this.playlist.length
    this.play(this.playlist, this.currentIndex)
  }

  /** 跳转到指定秒数 */
  seek(sec: number) {
    if (this.avPlayer) {
      this.isSeeking = true
      this.syncTime(sec)
      this.avPlayer.seek(sec * 1000)
    }
  }

  // ============ 播放器内核 ============
  private async startPlayer(url: string) {
    await this.releasePlayer()
    return new Promise<void>((resolve, reject) => {
      media.createAVPlayer().then((player) => {
        this.avPlayer = player
        let initialized = false
        let resolved = false
        const initTimer = setTimeout(() => {
          if (!initialized && !resolved) {
            resolved = true
            reject(new Error('AVPlayer init timeout'))
          }
        }, 15000)

        player.on('stateChange', (state: string) => {
          console.info('AVPlayer stateChange:', state)
          if (state === 'initialized') {
            initialized = true
            clearTimeout(initTimer)
            player.prepare().then(() => {
              player.play()
            }).catch((err: BusinessError) => {
              console.error('prepare error:', err.code, err.message)
              if (!resolved) {
                resolved = true
                reject(err)
              }
            })
          } else if (state === 'playing') {
            this.syncPlaying(true)
            this.startBgTask()
            this.updateSessionPlayState(true)
            if (!resolved) {
              resolved = true
              resolve()
            }
          } else if (state === 'paused' || state === 'stopped') {
            this.syncPlaying(false)
            this.stopBgTask()
            this.updateSessionPlayState(false)
          } else if (state === 'completed') {
            this.syncPlaying(false)
            this.stopBgTask()
            this.updateSessionPlayState(false)
            this.playNext()
          }
        })

        player.on('error', (err: BusinessError) => {
          console.error('AVPlayer error:', err.code, err.message)
          this.syncPlaying(false)
          this.stopBgTask()
          clearTimeout(initTimer)
          if (!resolved) {
            resolved = true
            reject(err)
          }
        })

        player.on('timeUpdate', (time: number) => {
          if (!this.isSeeking) {
            const sec = Math.floor(time / 1000)
            this.syncTime(sec)
            const lrcStr = AppStorage.get<string>('pm_lrc')
            if (lrcStr) {
              try {
                const lines = JSON.parse(lrcStr) as LrcLine[]
                if (lines.length > 0) {
                  this.syncLrcIndex(findLrcIndex(lines, time))
                }
              } catch (e) {
                // ignore
              }
            }
          }
        })

        player.on('durationUpdate', (dur: number) => {
          this.syncDuration(Math.floor(dur / 1000))
        })

        player.on('seekDone', () => {
          this.isSeeking = false
        })

        player.url = url
      }).catch((err: BusinessError) => {
        console.error('createAVPlayer error:', err.code, err.message)
        reject(err)
      })
    })
  }

  private async releasePlayer() {
    if (this.avPlayer) {
      try {
        this.avPlayer.off('stateChange')
        this.avPlayer.off('error')
        this.avPlayer.off('timeUpdate')
        this.avPlayer.off('durationUpdate')
        this.avPlayer.off('seekDone')
        await this.avPlayer.release()
      } catch (e) {
        console.error('releasePlayer error:', JSON.stringify(e))
      }
      this.avPlayer = null
    }
  }

  // ============ AVSession ============
  private async createSession() {
    if (this.session || !this.context) {
      return
    }
    try {
      this.session = await avSession.createAVSession(this.context, 'MusicFreeSession', 'audio')
      await this.session.activate()
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: this.context.abilityInfo.bundleName,
          abilityName: this.context.abilityInfo.name,
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
      }
      const agent = await wantAgent.getWantAgent(wantAgentInfo)
      await this.session.setLaunchAbility(agent)
      this.setSessionCommandListeners()
    } catch (e) {
      console.error('createSession error:', JSON.stringify(e))
    }
  }

  private setSessionCommandListeners() {
    if (!this.session) {
      return
    }
    try {
      this.session.on('play', () => {
        if (this.avPlayer && !AppStorage.get<boolean>('pm_playing')) {
          this.avPlayer.play()
        }
      })
      this.session.on('pause', () => {
        if (this.avPlayer && AppStorage.get<boolean>('pm_playing')) {
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

  private async updateSessionMetadata() {
    if (!this.session || !this.currentSong) {
      return
    }
    try {
      const metadata: avSession.AVMetadata = {
        assetId: this.currentSong.id ?? '',
        title: this.currentSong.name,
        artist: this.currentSong.singer,
        duration: (this.currentSong.duration_sec ?? 0) * 1000,
      }
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
      this.session.setAVMetadata(metadata).catch((err: BusinessError) => {
        console.error('setAVMetadata error:', err.code, err.message)
      })
    } catch (e) {
      console.error('updateSessionMetadata error:', JSON.stringify(e))
    }
  }

  private updateSessionPlayState(isPlay: boolean) {
    if (!this.session) {
      return
    }
    try {
      const state: avSession.AVPlaybackState = {
        state: isPlay ? avSession.PlaybackState.PLAYBACK_STATE_PLAY : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
        position: {
          elapsedTime: (AppStorage.get<number>('pm_time') ?? 0) * 1000,
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

  // ============ 后台任务 ============
  private startBgTask() {
    if (this.context) {
      BackgroundUtil.startContinuousTask(this.context)
    }
  }
  private stopBgTask() {
    if (this.context) {
      BackgroundUtil.stopContinuousTask(this.context)
    }
  }

  // ============ 最近播放 ============
  private static readonly RECENT_KEY = 'recent_songs'

  /** 从持久化存储加载最近播放到 AppStorage */
  loadRecent() {
    const arr = StorageManager.getStringArray(PlayerManager.RECENT_KEY)
    const recent: SongItem[] = arr.map((s: string) => {
      try {
        return JSON.parse(s) as SongItem
      } catch (e) {
        return null
      }
    }).filter((s: SongItem | null) => s !== null) as SongItem[]
    AppStorage.setOrCreate('recent_songs', JSON.stringify(recent))
  }

  private addRecent(song: SongItem) {
    const recent = this.getRecentList()
    // 去重并放到最前
    const filtered = recent.filter((s: SongItem) => s.name !== song.name || s.artists !== song.artists)
    filtered.unshift(song)
    const list = filtered.length > 20 ? filtered.slice(0, 20) : filtered
    AppStorage.setOrCreate('recent_songs', JSON.stringify(list))
    // 持久化
    StorageManager.putStringArray(PlayerManager.RECENT_KEY, list.map((s: SongItem) => JSON.stringify(s)))
  }

  /** 删除单条最近播放 */
  removeRecent(song: SongItem) {
    const recent = this.getRecentList()
    const filtered = recent.filter((s: SongItem) => s.name !== song.name || s.artists !== song.artists)
    AppStorage.setOrCreate('recent_songs', JSON.stringify(filtered))
    StorageManager.putStringArray(PlayerManager.RECENT_KEY, filtered.map((s: SongItem) => JSON.stringify(s)))
  }

  /** 清空最近播放 */
  clearRecent() {
    AppStorage.setOrCreate('recent_songs', '[]')
    StorageManager.putStringArray(PlayerManager.RECENT_KEY, [])
  }

  private getRecentList(): SongItem[] {
    const recentStr = AppStorage.get<string>('recent_songs')
    if (!recentStr) {
      return []
    }
    try {
      return JSON.parse(recentStr) as SongItem[]
    } catch (e) {
      return []
    }
  }

  /** 销毁所有资源 */
  destroy() {
    this.stopBgTask()
    this.destroySession()
    this.releasePlayer()
  }
}

export const playerManager = PlayerManager.getInstance()
