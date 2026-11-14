import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { common } from '@kit.AbilityKit'
import { SongDetail, SongItem } from '../viewmodles/commons'
import { playerManager } from '../utils/PlayerManager'
import { parseLrc, findLrcIndex, fmtMs, LrcLine } from '../utils/LrcUtils'
import { window } from '@kit.ArkUI'

@HMRouter({ pageUrl: 'player' })
@Entry
@Component
export struct PlayerPage {
  @StorageLink('pm_song') songStr: string = ''
  @StorageLink('pm_playing') isPlaying: boolean = false
  @StorageLink('pm_time') currentTime: number = 0
  @StorageLink('pm_duration') duration: number = 0
  @StorageLink('pm_lrc') lrcStr: string = ''
  @StorageLink('pm_lrcIndex') lrcIndex: number = -1
  @State isSeeking: boolean = false
  @State seekValue: number = 0

  async aboutToAppear() {
    // 仅当前页全屏沉浸式
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      const win = await window.getLastWindow(ctx)
      win.setWindowLayoutFullScreen(true)
    } catch (e) {
      console.error('setWindowLayoutFullScreen error:', JSON.stringify(e))
    }
  }

  async aboutToDisappear() {
    // 恢复正常布局
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      const win = await window.getLastWindow(ctx)
      win.setWindowLayoutFullScreen(false)
    } catch (e) {
      console.error('restore window layout error:', JSON.stringify(e))
    }
  }

  // 解析缓存：SongDetail 含歌词全文，build 期间多次解析代价高
  private songCacheKey: string = ''
  private songCache: SongDetail | null = null
  private lrcCacheKey: string = ''
  private lrcCache: LrcLine[] = []

  private getSong(): SongDetail | null {
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

  private getLrcLines(): LrcLine[] {
    if (!this.lrcStr) {
      this.lrcCacheKey = ''
      this.lrcCache = []
      return this.lrcCache
    }
    if (this.lrcCacheKey === this.lrcStr) {
      return this.lrcCache
    }
    let lines: LrcLine[] = []
    try {
      lines = JSON.parse(this.lrcStr) as LrcLine[]
    } catch (e) {
      lines = []
    }
    this.lrcCacheKey = this.lrcStr
    this.lrcCache = lines
    return lines
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 背景：封面图模糊
      if (this.getSong()?.cover_url) {
        Image(this.getSong()!.cover_url)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(80)
          .opacity(0.6)
      }
      // 半透明遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.45)')

      // 内容
      Column() {
        // 顶部栏
        Row() {
          SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause') : $r('sys.symbol.play_fill'))
            .fontSize(20)
            .fontColor([Color.White])
            .opacity(0)
          Text('正在播放')
            .fontSize(15)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(24)
            .fontColor([Color.White])
            .onClick(() => {
              HMRouterMgr.pop()
            })
        }
        .width('100%')
        .height(56)
        .padding({ top: 36, left: 16, right: 16 })

        // 封面图
        Column() {
          if (this.getSong()?.cover_url) {
            Image(this.getSong()!.cover_url)
              .width(260)
              .height(260)
              .borderRadius(130)
              .objectFit(ImageFit.Cover)
              .rotate({ angle: this.isPlaying ? 360 : 0 })
              .animation({ duration: 20000, curve: Curve.Linear, iterations: -1 })
              .shadow({
                radius: 30,
                color: 'rgba(0,0,0,0.5)',
                offsetX: 0,
                offsetY: 10
              })
          } else {
            Column() {
              Text('♪')
                .fontSize(80)
                .fontColor(Color.White)
            }
            .width(260)
            .height(260)
            .borderRadius(130)
            .backgroundColor('rgba(255,255,255,0.15)')
            .justifyContent(FlexAlign.Center)
          }
        }
        .margin({ top: 30, bottom: 24 })

        // 歌名歌手
        Text(this.getSong()?.name ?? '暂无歌曲')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 24, right: 24 })
        Text(this.getSong()?.singer ?? '')
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.7)')
          .margin({ top: 6 })
          .padding({ left: 24, right: 24 })

        // 歌词区域
        Column() {
          if (this.getLrcLines().length === 0) {
            Text('暂无歌词')
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.4)')
          } else {
            List() {
              ForEach(this.getLrcLines(), (line: LrcLine, index: number) => {
                ListItem() {
                  Text(line.text)
                    .fontSize(index === this.lrcIndex ? 16 : 13)
                    .fontWeight(index === this.lrcIndex ? FontWeight.Bold : FontWeight.Normal)
                    .fontColor(index === this.lrcIndex ? '#FFFFFF' : 'rgba(255,255,255,0.5)')
                    .opacity(index === this.lrcIndex ? 1 : 0.5)
                    .textAlign(TextAlign.Center)
                    .width('100%')
                }
              }, (line: LrcLine, index: number) => `${index}_${line.time}`)
            }
            .width('100%')
            .height(140)
            .scrollBar(BarState.Off)
            .alignListItem(ListItemAlign.Center)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ left: 24, right: 24 })
        .margin({ top: 20 })

        // 进度条
        Column() {
          Slider({
            value: this.isSeeking ? this.seekValue : this.currentTime,
            min: 0,
            max: this.duration > 0 ? this.duration : 1,
            step: 1,
            style: SliderStyle.OutSet
          })
            .width('100%')
            .blockColor('#FFFFFF')
            .selectedColor('#FFFFFF')
            .trackColor('rgba(255,255,255,0.3)')
            .onChange((value: number, mode: SliderChangeMode) => {
              if (mode === SliderChangeMode.Begin) {
                this.isSeeking = true
              } else if (mode === SliderChangeMode.Moving) {
                this.seekValue = value
              } else if (mode === SliderChangeMode.End) {
                this.isSeeking = false
                playerManager.seek(value)
              }
            })
          Row() {
            Text(fmtMs(this.currentTime * 1000))
              .fontSize(11)
              .fontColor('rgba(255,255,255,0.6)')
            Blank()
            Text(fmtMs(this.duration * 1000))
              .fontSize(11)
              .fontColor('rgba(255,255,255,0.6)')
          }
          .width('100%')
          .margin({ top: 4 })
        }
        .width('100%')
        .padding({ left: 24, right: 24 })

        // 控制按钮
        Row() {
          SymbolGlyph($r('sys.symbol.backward_end_fill'))
            .fontSize(32)
            .fontColor(['#FFFFFF'])
            .onClick(() => {
              playerManager.playPrev()
            })
          Column() {
            SymbolGlyph(this.isPlaying ? $r('sys.symbol.pause') : $r('sys.symbol.play_fill'))
              .fontSize(44)
              .fontColor(['#FFFFFF'])
          }
          .width(64)
          .height(64)
          .borderRadius(32)
          .backgroundColor('rgba(255,255,255,0.2)')
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            playerManager.togglePlay()
          })

          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize(32)
            .fontColor(['#FFFFFF'])
            .onClick(() => {
              playerManager.playNext()
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
        .alignItems(VerticalAlign.Center)

        // .padding({
        //   left: 40,
        //   right: 40,
        //   top: 16,
        //   bottom: 48
        // })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')

    // .expandSafeArea()
  }
}
