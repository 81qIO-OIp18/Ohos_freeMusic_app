import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { GlobalVariable } from 'library'
import { GameItem } from '../viewmodles/commons'
import { DetailNavBar } from '../components/DetailNavBar'

@HMRouter({ pageUrl: 'gamepage' })
@Component
export struct GamePage {
  @State gameMessage: GameItem = {
    title: '',
    id: '',
    namespace: '',
    desc: '',
    seller: { id: '', name: '' },
    status: 0,
    start_time: '',
    end_time: ''
  }
  @State expanded: boolean = false
  @StorageProp(GlobalVariable.SAFE_TOP_HEIGHT)
  topHeight: number = 0

  aboutToAppear(): void {
    const param = HMRouterMgr.getCurrentParam() as GameItem
    if (param) {
      this.gameMessage = param
    }
  }

  // "2026-11-06 00:00:00" -> "2026.11.06"
  formatDate(date: string): string {
    return date.substring(0, 10).replaceAll('-', '.')
  }

  // 倒计时：还剩 X 天 X 小时
  getCountdown(): string {
    const endTime = this.gameMessage.end_time.replaceAll('-', '/')
    const diff = new Date(endTime).getTime() - Date.now()
    if (diff <= 0) {
      return '已结束'
    }
    const days = Math.floor(diff / 86400000)
    const hours = Math.floor((diff % 86400000) / 3600000)
    return `还剩 ${days} 天 ${hours} 小时`
  }

  // 简介大约超过 4 行（按 14vp 字号估算约 90 字）才显示展开/收起
  needToggle(): boolean {
    return this.expanded || this.gameMessage.desc.length > 90
  }

  build() {
    Column() {
      // 1. 固定导航栏
      DetailNavBar({
        title: '资讯详情',
        onBack: () => {
          HMRouterMgr.pop()
        }
      })
      Column() {
        // 主体内容紧贴导航栏下方，靠上排列，高度撑满剩余空间
        Scroll() {
          Column() {
            // 2. 顶部占位色块区（160vp，铺满左右）
            Stack({ alignContent: Alignment.TopEnd }) {
              Row() {
                SymbolGlyph($r('sys.symbol.gamecontroller'))
                  .fontSize(56)
                  .fontColor([Color.White])
                  .opacity(0.95)
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)

              Text(this.gameMessage.status === 1 ? '可领取' : '即将开始')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.gameMessage.status === 1 ? $r('app.color.accent') : $r('app.color.tag_pending_text'))
                .padding({
                  left: 10,
                  right: 10,
                  top: 4,
                  bottom: 4
                })
                .borderRadius(10)
                .backgroundColor($r('app.color.tag_overlay_bg'))
                .margin({ top: 14, right: 16 })
            }
            .width('100%')
            .height(160)
            .linearGradient({
              angle: 135,
              colors: [['#0B1F4B', 0.0], ['#0A4FA8', 0.5], ['#12B5D8', 1.0]]
            })

            // 3. 游戏名称区
            Column() {
              Text(this.gameMessage.title)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text(this.gameMessage.seller.name)
                .fontSize(12)
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 6 })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding({ left: 20, right: 20, top: 18 })

            // 6. 游戏简介模块
            Column() {
              Text('游戏简介')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .width('100%')

              Text(this.gameMessage.desc)
                .fontSize(14)
                .lineHeight(22)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .margin({ top: 8 })
                .maxLines(this.expanded ? 99 : 4)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              if (this.needToggle()) {
                Row() {
                  Blank()
                  Text(this.expanded ? '收起' : '展开')
                    .fontSize(13)
                    .fontColor($r('app.color.accent'))
                    .onClick(() => {
                      this.expanded = !this.expanded
                    })
                }
                .width('100%')
                .margin({ top: 8 })
              }
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 20 })

            // 4. 限时领取模块（独立卡片）
            Column() {
              Column() {
                Row() {
                  Text('领取时间')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Blank()
                  Text(this.getCountdown())
                    .fontSize(12)
                    .fontColor(this.gameMessage.status === 1 ? $r('app.color.accent') : $r('app.color.text_tertiary'))
                }
                .width('100%')

                Row() {
                  Text(this.formatDate(this.gameMessage.start_time))
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                  Text('至')
                    .fontSize(12)
                    .fontColor($r('app.color.text_tertiary'))
                    .margin({ left: 8, right: 8 })
                  Text(this.formatDate(this.gameMessage.end_time))
                    .fontSize(13)
                    .fontWeight(this.gameMessage.status === 1 ? FontWeight.Medium : FontWeight.Normal)
                    .fontColor(this.gameMessage.status === 1 ? $r('app.color.accent') : $r('app.color.text_secondary'))
                }
                .width('100%')
                .margin({ top: 10 })
              }
              .width('100%')
              .padding(16)
              .borderRadius(16)
              .backgroundColor($r('app.color.card_bg'))
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 18 })
          }
          .width('100%')
          .padding({ bottom: 24 })
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))

    }
  }
}
