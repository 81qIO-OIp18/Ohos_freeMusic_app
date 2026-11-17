import { HMRouterMgr } from '@hadss/hmrouter'
import { common } from '@kit.AbilityKit'
import { Throttle } from 'library'
import { SongItem, SongDetail } from '../viewmodles/commons'
import { playerManager } from '../utils/PlayerManager'
import { fmtMs } from '../utils/LrcUtils'
import { PlayerPanel } from '../pages/PlayerPage'

/**
 * 音乐首页：最近播放 + 搜索入口 + 迷你播放栏
 */
@Component
export struct MusicHome {
  @StorageLink('recent_songs') recentStr: string = '[]'
  @StorageLink('pm_song') songStr: string = ''
  @StorageLink('pm_playing') isPlaying: boolean = false
  @StorageLink('pm_time') currentTime: number = 0
  @StorageLink('pm_duration') duration: number = 0
  // 全屏模态播放器显隐
  @State showPlayer: boolean = false
  // 点击防抖：500ms 内的重复点击直接忽略
  private clickThrottle: Throttle = new Throttle(500)

  private canClick(): boolean {
    return this.clickThrottle.canRun()
  }

  @Builder
  playerModal() {
    PlayerPanel({
      onClose: () => {
        this.showPlayer = false
      }
    })
  }

  // 解析缓存：build 期间同一份 JSON 会被访问多次，缓存后只解析一次
  private recentCacheKey: string = ''
  private recentCache: SongItem[] = []
  private songCacheKey: string = ''
  private songCache: SongDetail | null = null

  private getRecent(): SongItem[] {
    if (this.recentCacheKey === this.recentStr) {
      return this.recentCache
    }
    let list: SongItem[] = []
    try {
      list = JSON.parse(this.recentStr) as SongItem[]
    } catch (e) {
      list = []
    }
    this.recentCacheKey = this.recentStr
    this.recentCache = list
    return list
  }

  private getCurrentSong(): SongDetail | null {
    if (!this.songStr) {
      this.songCacheKey = ''
      this.songCache = null
      return null
    }
    if (this.songCacheKey === this.songStr) {
      return this.songCache
    }
    let song: SongDetail | null = null
    try {
      song = JSON.parse(this.songStr) as SongDetail
    } catch (e) {
      song = null
    }
    this.songCacheKey = this.songStr
    this.songCache = song
    return song
  }

  aboutToAppear() {
    // 注入 context 给 PlayerManager
    playerManager.setContext(getContext(this) as common.UIAbilityContext)
    // 从持久化存储加载最近播放（确保页面显示时数据已就绪）
    playerManager.loadRecent()
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('拾音')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: 16 })

      // 搜索栏（点击跳转搜索页）
      Row() {
        Image($r("app.media.search"))
          .width(16)
          .height(16)
          .margin({ right: 8 })
        Text('搜索歌曲、歌手')
          .fontSize(15)
          .fontColor($r('app.color.text_tertiary'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(42)
      .padding({ left: 14, right: 14 })
      .borderRadius(21)
      .backgroundColor($r('app.color.card_bg'))
      .onClick(() => {
        if (!this.canClick()) {
          return
        }
        HMRouterMgr.push({ pageUrl: 'search' })
      })

      // 最近播放
      Column() {
        if (this.getRecent().length === 0) {
          Column() {
            Text('🎵')
              .fontSize(48)
            Text('还没有听过的歌')
              .fontSize(14)
              .fontColor($r('app.color.text_tertiary'))
              .margin({ top: 12 })
            Text('点击上方搜索框，发现好音乐')
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
              .opacity(0.7)
              .margin({ top: 4 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Row() {
            Text('最近听过')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text(`${this.getRecent().length} 首`)
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
              .margin({ left: 8 })
            Blank()
            Text('清空')
              .fontSize(13)
              .fontColor($r('app.color.text_tertiary'))
              .onClick(() => {
                if (!this.canClick()) {
                  return
                }
                playerManager.clearRecent()
              })
          }
          .width('100%')
          .margin({ top: 20, bottom: 8 })

          List({ space: 2 }) {
            ForEach(this.getRecent(), (song: SongItem, index: number) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(song.name)
                      .fontSize(15)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(song.artists)
                      .fontSize(12)
                      .fontColor($r('app.color.text_tertiary'))
                      .margin({ top: 3 })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  SymbolGlyph($r('sys.symbol.play_round_triangle_fill'))
                    .fontSize(22)
                    .fontColor([$r('app.color.accent')])
                    .onClick(() => {
                      if (!this.canClick()) {
                        return
                      }
                      playerManager.play(this.getRecent(), index)
                    })

                  Text('✕')
                    .fontSize(16)
                    .fontColor($r('app.color.text_tertiary'))
                    .margin({ left: 12 })
                    .onClick(() => {
                      if (!this.canClick()) {
                        return
                      }
                      playerManager.removeRecent(song)
                    })
                }
                .width('100%')
                .padding({
                  left: 4,
                  right: 4,
                  top: 12,
                  bottom: 12
                })
              }
              .onClick(() => {
                if (!this.canClick()) {
                  return
                }
                playerManager.play(this.getRecent(), index)
              })
            }, (song: SongItem, index: number) => `${index}_${song.name}`)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height("100%")
      .layoutWeight(1)

      // 迷你播放栏
      if (this.getCurrentSong()) {
        Stack() {
          Row() {
            // 封面
            if (this.getCurrentSong()!.cover_url) {
              Image(this.getCurrentSong()!.cover_url)
                .width(44)
                .height(44)
                .borderRadius(8)
                .objectFit(ImageFit.Cover)
            } else {
              Column() {
                Text('♪')
                  .fontSize(22)
                  .fontColor('#FFFFFF')
              }
              .width(44)
              .height(44)
              .borderRadius(8)
              .backgroundColor($r('app.color.accent'))
              .justifyContent(FlexAlign.Center)
            }
            // 歌名 + 进度
            Column() {
              Text(this.getCurrentSong()!.name)
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(`${fmtMs(this.currentTime * 1000)} / ${fmtMs(this.duration * 1000)}`)
                .fontSize(11)
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 10 })
            .onClick(() => {
              if (!this.canClick()) {
                return
              }
              this.showPlayer = true
            })

            // 播放/暂停（两个图标叠放，切换时淡入淡出 + 缩放，避免生硬跳变）
            Stack() {
              SymbolGlyph($r('sys.symbol.play_fill'))
                .fontSize(26)
                .fontColor([$r('app.color.text_primary')])
                .opacity(this.isPlaying ? 0 : 1)
                .scale({
                  x: this.isPlaying ? 0.6 : 1,
                  y: this.isPlaying ? 0.6 : 1
                })
                .animation({ duration: 200, curve: Curve.EaseOut })
              SymbolGlyph($r('sys.symbol.pause'))
                .fontSize(26)
                .fontColor([$r('app.color.text_primary')])
                .opacity(this.isPlaying ? 1 : 0)
                .scale({
                  x: this.isPlaying ? 1 : 0.6,
                  y: this.isPlaying ? 1 : 0.6
                })
                .animation({ duration: 200, curve: Curve.EaseOut })
            }
            .width(36)
            .height(36)
            .onClick(() => {
              //添加0.5s的延时
              setTimeout(() => {
                if (!this.canClick()) {
                  return
                }
                playerManager.togglePlay()
              }, 500)
            })
          }
          .width('100%')
          .padding(10)
          .borderRadius(14)
          .backgroundColor($r('app.color.card_bg'))
          .margin({ top: 8, bottom: 8 })
        }
      }
    }
    .width('100%')
    .height('100%')
    .bindContentCover(this.showPlayer, this.playerModal(), {
      modalTransition: ModalTransition.DEFAULT,
      backgroundColor: '#000000',
      onDisappear: () => {
        this.showPlayer = false
      }
    })
  }
}
