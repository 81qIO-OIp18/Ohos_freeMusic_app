/**
 * 其他平台占位页面（非 Epic 的应用界面）
 */
@Component
export struct OtherHome {
  platformName: string = ''

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
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.page_bg'))
  }
}
