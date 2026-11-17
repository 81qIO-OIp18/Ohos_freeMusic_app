import { common } from '@kit.AbilityKit'
import { GlobalVariable, Throttle } from 'library'
import { SongDetail, SongItem } from '../viewmodles/commons'
import { playerManager } from '../utils/PlayerManager'
import { parseLrc, findLrcIndex, fmtMs, LrcLine } from '../utils/LrcUtils'
import { window } from '@kit.ArkUI'

/**
 * 全屏模态播放器（通过 bindContentCover 弹出，非独立页面）
 */
@Component
export struct PlayerPanel {
  onClose: () => void = () => {
  }
  @StorageLink('pm_song') songStr: string = ''
  @StorageLink('pm_playing') @Watch('onPlayingChange') isPlaying: boolean = false
  @StorageLink('pm_time') currentTime: number = 0
  @StorageLink('pm_duration') duration: number = 0
  @StorageLink('pm_lrc') lrcStr: string = ''
  @StorageLink('pm_lrcIndex') @Watch('onLrcIndexChange') lrcIndex: number = -1
  // 状态栏高度（应用已开启沉浸式，内容延伸到状态栏下方）
  @StorageProp(GlobalVariable.SAFE_TOP_HEIGHT) topHeight: number = 0
  @State isSeeking: boolean = false
  @State seekValue: number = 0
  // 封面旋转角度（定时器驱动，播放时持续旋转、暂停定格）
  @State coverAngle: number = 0
  private rotateTimer: number = -1
  // 歌词列表滚动控制器
  private lyricScroller: Scroller = new Scroller()
  // 点击防抖：300ms 内的重复点击直接忽略（播放控制需要相对灵敏）
  private clickThrottle: Throttle = new Throttle(300)

  private canClick(): boolean {
    return this.clickThrottle.canRun()
  }

  private startRotate() {
    if (this.rotateTimer !== -1) {
      return
    }
    // 每 50ms 推进 0.9°（约 20 秒一圈），配合 rotate 上的线性补间实现平滑旋转
    this.rotateTimer = setInterval(() => {
      this.coverAngle = (this.coverAngle + 0.9) % 360
    }, 50)
  }

  private stopRotate() {
    if (this.rotateTimer !== -1) {
      clearInterval(this.rotateTimer)
      this.rotateTimer = -1
    }
  }

  onPlayingChange() {
    if (this.isPlaying) {
      this.startRotate()
    } else {
      this.stopRotate()
    }
  }

  // 当前歌词行变化时，自动滚动到居中位置
  onLrcIndexChange() {
    if (this.lrcIndex < 0) {
      return
    }
    const target = this.lrcIndex
    // 延迟到本帧布局完成后再滚动，避免列表尚未渲染导致滚动无效
    setTimeout(() => {
      try {
        this.lyricScroller.scrollToIndex(target, true, ScrollAlign.CENTER)
      } catch (e) {
        console.error('scrollToIndex error:', JSON.stringify(e))
      }
    }, 50)
  }

  async aboutToAppear() {
    // 只把系统栏染成深色与播放页保持一致，不改窗口布局
    // （改 setWindowLayoutFullScreen 会触发窗口重新布局，关闭后首页内容整体下移）
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      const win = await window.getLastWindow(ctx)
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: '#FFFFFF',
        navigationBarContentColor: '#FFFFFF'
      })
    } catch (e) {
      console.error('setWindowSystemBarProperties error:', JSON.stringify(e))
    }
    // 打开面板时定位到当前歌词行
    setTimeout(() => {
      this.onLrcIndexChange()
    }, 200)
    // 若已在播放，启动封面旋转
    if (this.isPlaying) {
      this.startRotate()
    }
  }

  async aboutToDisappear() {
    // 停止旋转定时器
    this.stopRotate()
    // 恢复系统栏配色
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      const win = await window.getLastWindow(ctx)
      win.setWindowSystemBarProperties({
        statusBarColor: '#FFFFFF',
        navigationBarColor: '#FFFFFF',
        statusBarContentColor: '#000000',
        navigationBarContentColor: '#000000'
      })
    } catch (e) {
      console.error('restore window system bar error:', JSON.stringify(e))
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
              if (!this.canClick()) {
                return
              }
              this.onClose()
            })
        }
        .width('100%')
        .height(56)
        .padding({ top: this.topHeight + 8, left: 16, right: 16 })

        // 封面图
        Column() {
          if (this.getSong()?.cover_url) {
            Image(this.getSong()!.cover_url)
              .width(260)
              .height(260)
              .borderRadius(130)
              .objectFit(ImageFit.Cover)
              .rotate({ angle: this.coverAngle })
              // 线性补间：把离散的角度更新插值成连续旋转，消除卡顿
              .animation({ duration: 50, curve: Curve.Linear })
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
            List({ scroller: this.lyricScroller }) {
              ForEach(this.getLrcLines(), (line: LrcLine, index: number) => {
                ListItem() {
                  Text(line.text)
                    .fontSize(index === this.lrcIndex ? 18 : 14)
                    .fontWeight(index === this.lrcIndex ? FontWeight.Bold : FontWeight.Normal)
                    .fontColor(index === this.lrcIndex ? '#FFFFFF' : 'rgba(255,255,255,0.5)')
                    .opacity(index === this.lrcIndex ? 1 : 0.5)
                    .textAlign(TextAlign.Center)
                    .width('100%')
                }
                .padding({ top: 10, bottom: 10 })
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
              if (!this.canClick()) {
                return
              }
              playerManager.playPrev()
            })
          Column() {
            // 播放/暂停（两个图标叠放，切换时淡入淡出 + 缩放）
            Stack() {
              SymbolGlyph($r('sys.symbol.play_fill'))
                .fontSize(44)
                .fontColor(['#FFFFFF'])
                .opacity(this.isPlaying ? 0 : 1)
                .scale({
                  x: this.isPlaying ? 0.6 : 1,
                  y: this.isPlaying ? 0.6 : 1
                })
                .animation({ duration: 200, curve: Curve.EaseOut })
              SymbolGlyph($r('sys.symbol.pause'))
                .fontSize(44)
                .fontColor(['#FFFFFF'])
                .opacity(this.isPlaying ? 1 : 0)
                .scale({
                  x: this.isPlaying ? 1 : 0.6,
                  y: this.isPlaying ? 1 : 0.6
                })
                .animation({ duration: 200, curve: Curve.EaseOut })
            }
            .width(48)
            .height(48)
          }
          .width(64)
          .height(64)
          .borderRadius(32)
          .backgroundColor('rgba(255,255,255,0.2)')
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            if (!this.canClick()) {
              return
            }
            playerManager.togglePlay()
          })

          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize(32)
            .fontColor(['#FFFFFF'])
            .onClick(() => {
              if (!this.canClick()) {
                return
              }
              playerManager.playNext()
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
        .alignItems(VerticalAlign.Center)
        .padding({ bottom: 24 })
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
