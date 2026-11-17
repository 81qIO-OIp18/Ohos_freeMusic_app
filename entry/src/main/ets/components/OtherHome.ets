/**
 * 其他平台占位页面（非 Epic 的应用界面）
 */
import { Throttle } from 'library'

@Component
export struct OtherHome {
  platformName: string = ''
  onBack: () => void = () => {
  }
  // 点击防抖：500ms 内的重复点击直接忽略
  private clickThrottle: Throttle = new Throttle(500)

  build() {
    Column() {
      Text(this.platformName)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Text('该平台资讯正在建设中，敬请期待~')
        .fontSize(14)
        .fontColor($r('app.color.text_tertiary'))
        .margin({ top: 12 })

      Button('返回选择平台')
        .margin({ top: 32 })
        .height(40)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor($r('app.color.accent'))
        .borderRadius(20)
        .padding({ left: 24, right: 24 })
        .onClick(() => {
          if (!this.clickThrottle.canRun()) {
            return
          }
          this.onBack()
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.page_bg'))
  }
}
