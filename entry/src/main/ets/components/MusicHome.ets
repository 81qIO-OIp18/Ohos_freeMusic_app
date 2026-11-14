import { HMRouterMgr } from '@hadss/hmrouter'
import { common } from '@kit.AbilityKit'
import { SongItem, SongDetail } from '../viewmodles/commons'
import { playerManager } from '../utils/PlayerManager'
import { fmtMs } from '../utils/LrcUtils'

/**
 * 音乐首页：最近播放 + 搜索入口 + 迷你播放栏
 */
@Component
export struct MusicHome {
  onSwitchPlatform: () => void = () => {
  }
  @StorageLink('recent_songs') recentStr: string = '[]'
  @StorageLink('pm_song') songStr: string = ''
  @StorageLink('pm_playing') isPlaying: boolean = false
  @StorageLink('pm_time') currentTime: number = 0
  @StorageLink('pm_duration') duration: number = 0

  private getRecent(): SongItem[] {
    try {
      return JSON.parse(this.recentStr) as SongItem[]
    } catch (e) {
      return []
    }
  }

  private getCurrentSong(): SongDetail | null {
    if (!this.songStr) {
      return null
    }
    try {
      return JSON.parse(this.songStr) as SongDetail
    } catch (e) {
      return null
    }
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
        Text('免费音乐')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text('切换平台')
          .fontSize(13)
          .fontColor($r('app.color.accent'))
          .onClick(() => {
            this.onSwitchPlatform()
          })
      }
      .width('100%')
      .margin({ bottom: 16 })

      // 搜索栏（点击跳转搜索页）
      Row() {
        Text('🔍')
          .fontSize(16)
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
                      playerManager.play(this.getRecent(), index)
                    })

                  Text('✕')
                    .fontSize(16)
                    .fontColor($r('app.color.text_tertiary'))
                    .margin({ left: 12 })
                    .onClick(() => {
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
      .layoutWeight(1)

      // 迷你播放栏
      if (this.getCurrentSong()) {
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
            HMRouterMgr.push({ pageUrl: 'player' })
          })

          // 播放/暂停
          SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause') : $r('sys.symbol.play_fill'))
            .fontSize(26)
            .fontColor([$r('app.color.text_primary')])
            .onClick(() => {
              playerManager.togglePlay()
            })
        }
        .width('100%')
        .padding(10)
        .borderRadius(14)
        .backgroundColor($r('app.color.card_bg'))
        .margin({ top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')

    // .padding({ left: 16, right: 16, top: 12 })
  }
}
