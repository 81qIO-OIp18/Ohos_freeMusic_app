/**
 * 详情页顶部导航栏（固定）
 * 返回箭头 + 标题
 */
import { Throttle } from 'library'

@Component
export struct DetailNavBar {
  title: string = '游戏详情'
  onBack: () => void = () => {
  }
  // 点击防抖：500ms 内的重复点击直接忽略，避免连续返回
  private clickThrottle: Throttle = new Throttle(500)

  build() {
    Row() {
      Image($r('app.media.back'))
        .width(24)
        .height(24)
        .fillColor($r('app.color.icon_primary'))
        .onClick(() => {
          if (!this.clickThrottle.canRun()) {
            return
          }
          this.onBack()
        })
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 8 })
      Blank()
    }
    .width('100%')
    .height(44)
    .padding({ right: 10 })
  }
}
