import { HMNavigation, HMRouterMgr } from '@hadss/hmrouter'
import { AttributeUpdater } from '@kit.ArkUI'
import { GlobalVariable, Throttle } from 'library'
import { gerEPIC_free_game_API, gerEPIC_free_game_MOCK_API } from '../apis'
import { GameItem } from '../viewmodles/commons'
import { OtherHome } from '../components/OtherHome'
import { MusicHome } from '../components/MusicHome'

interface PlatformOption {
  key: string
  name: string
  desc: string
  available: boolean
}

@Entry
@Component
struct Index {
  modifier: HDMModifier = new HDMModifier() // 继承并实例化
  @State list: GameItem[] = []
  @State isLoading: boolean = true
  @StorageProp(GlobalVariable.SAFE_TOP_HEIGHT)
  topHeight: number = 0
  @State refreshIng: boolean = false // 控制下拉刷新
  @State refreshStatus: RefreshStatus = RefreshStatus.Inactive
  private refreshThrottle: Throttle = new Throttle(3000) // 刷新节流：3 秒内最多请求一次
  private clickThrottle: Throttle = new Throttle(800) // 点击节流：首次立即跳转，800ms 内重复点击忽略
  @State selectedPlatform: string = '' // 已选择进入的平台，空字符串表示还在选择页
  // 可选平台列表：Epic 已接入，其他为占位
  private platforms: PlatformOption[] = [
    // {
    //   key: 'epic',
    //   name: 'Epic',
    //   desc: '限时免费游戏资讯',
    //   available: true
    // },
    {
      key: 'music',
      name: 'Music',
      desc: '免费的音乐平台',
      available: true
    },
    // {
    //   key: '暂无',
    //   name: 'GOG',
    //   desc: '无 DRM 免费游戏',
    //   available: false
    // }
  ]

  async getEPIC() {
    try {
      // 测试阶段用假数据，接真实接口时换成 gerEPIC_free_game_API()
      // this.list = await gerEPIC_free_game_MOCK_API()
      this.list = await gerEPIC_free_game_API()

    } catch (e) {
      console.error('getEPIC error:', JSON.stringify(e))
    } finally {
      // 无论成功失败都结束加载态
      this.isLoading = false
    }
  }

  aboutToAppear(): void {
    this.getEPIC()
  }

  // 下拉刷新
  async refresh() {
    // 节流：短时间重复下拉直接忽略，避免重复请求
    if (!this.refreshThrottle.canRun()) {
      this.refreshIng = false
      return
    }
    await this.getEPIC()
    this.refreshIng = false
  }

  // 可以领取的游戏数量（status 为 1 表示已开启）
  getClaimableCount(): number {
    return this.list.filter((item: GameItem) => item.status === 1).length
  }

  // "2026-11-06 00:00:00" -> "11.06"
  formatDate(date: string): string {
    return date.substring(5, 10).replace('-', '.')
  }

  // 根据平台 key 取平台显示名
  getPlatformName(key: string): string {
    const target = this.platforms.find((item: PlatformOption) => item.key === key)
    return target ? target.name : key
  }

  build() {
    Column() {
      HMNavigation({
        navigationId: GlobalVariable.MAIN_PAGE_ID, // 唯一的标识 通过这个标识可以拿到对象
        homePageUrl: GlobalVariable.MAIN_PAGE, // 通过这个地址可以回跳到主页 /main
        options: {
          modifier: this.modifier // 作用是什么？ Navigation组件的一些属性需要配置
        }
      }) {
        if (this.selectedPlatform === '') {
          // 平台选择页：刚进入应用时选择要进入的平台
          Column() {
            Text('选择要进入的平台')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 24 })

            ForEach(this.platforms, (item: PlatformOption) => {
              Row() {
                Column() {
                  Text(item.name)
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Text(item.desc)
                    .fontSize(12)
                    .fontColor($r('app.color.text_tertiary'))
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (item.available) {
                  Text('进入')
                    .fontSize(12)
                    .fontColor($r('app.color.accent'))
                } else {
                  Text('敬请期待')
                    .fontSize(11)
                    .fontColor($r('app.color.text_tertiary'))
                }
              }
              .width('100%')
              .padding(18)
              .borderRadius(16)
              .backgroundColor($r('app.color.card_bg'))
              .margin({ bottom: 12 })
              .onClick(() => {
                this.selectedPlatform = item.key
              })
            }, (item: PlatformOption) => item.key)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ left: 20, right: 20 })
        } else if (this.selectedPlatform === 'epic') {
          if (this.isLoading) {
            // 加载动画，数据加载完成后再显示主体内容
            Column() {
              LoadingProgress()
                .width(56)
                .height(56)
                .color($r('app.color.accent'))
              Text('加载中，客官稍等一下哦~~~')
                .fontSize(13)
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 12 })
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else {
            // 上层显示可以领取的游戏数量
            // 顶部：切换平台入口
            Row() {
              Blank()
              Text('切换平台')
                .fontSize(13)
                .fontColor($r('app.color.accent'))
                .onClick(() => {
                  this.selectedPlatform = ''
                })
            }
            .width('100%')
            .margin({ bottom: 12 })

            Row() {
              Column() {
                Text('Epic 喜加一资讯')
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text('限时免费领取')
                  .fontSize(12)
                  .fontColor($r('app.color.text_tertiary'))
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Row() {
                Text(this.getClaimableCount().toString())
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                Text('款可领取')
                  .fontSize(11)
                  .fontColor('#FFFFFF')
                  .opacity(0.8)
                  .margin({ left: 4 })
              }
              .padding({
                left: 14,
                right: 14,
                top: 8,
                bottom: 8
              })
              .borderRadius(16)
              .backgroundColor($r('app.color.accent'))
            }
            .width('100%')

            // 下层用 list 容器包裹将 list 主体内容显示，外层 Refresh 支持下拉刷新
            Refresh({ refreshing: $$this.refreshIng }) {
              List({ space: 12 }) {
                ForEach(this.list, (item: GameItem) => {
                  ListItem() {
                    Column() {
                      Row() {
                        Text(item.title)
                          .fontSize(17)
                          .fontWeight(FontWeight.Medium)
                          .fontColor($r('app.color.text_primary'))
                          .maxLines(2)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .layoutWeight(1)
                        Text(item.status === 1 ? '可领取' : '即将开始')
                          .fontSize(11)
                          .fontColor(item.status === 1 ? '#FFFFFF' : $r('app.color.tag_pending_text'))
                          .padding({
                            left: 8,
                            right: 8,
                            top: 3,
                            bottom: 3
                          })
                          .borderRadius(8)
                          .backgroundColor(item.status === 1 ? $r('app.color.accent') : $r('app.color.tag_pending_bg'))
                          .margin({ left: 8 })
                      }
                      .width('100%')
                      .alignItems(VerticalAlign.Top)

                      Text(item.desc)
                        .fontSize(12)
                        .fontColor($r('app.color.text_body'))
                        .lineHeight(18)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                        .margin({ top: 8 })

                      Row() {
                        Text(item.seller.name)
                          .fontSize(11)
                          .fontColor($r('app.color.text_tertiary'))
                          .layoutWeight(1)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(`${this.formatDate(item.start_time)} - ${this.formatDate(item.end_time)}`)
                          .fontSize(11)
                          .fontColor($r('app.color.text_tertiary'))
                          .margin({ left: 8 })
                      }
                      .width('100%')
                      .margin({ top: 12 })
                    }
                    .width('100%')
                    .padding(16)
                    .borderRadius(16)
                    .backgroundColor($r('app.color.card_bg'))
                  }
                  .onClick(() => {
                    // 节流（首次立即执行）：立即跳转，避免防抖等待造成的点击延迟
                    if (!this.clickThrottle.canRun()) {
                      return
                    }
                    HMRouterMgr.push({
                      pageUrl: "gamepage",
                      param: item
                    }, {
                      onArrival: () => {
                        console.info('[HomeView] push onArrival')
                      },
                      onLost: () => {
                        console.info('[HomeView] push onLost: page not found')
                      }
                    })
                  })
                }, (item: GameItem) => item.id)

                // 列表底部提示，没有更多数据时显示
                ListItem() {
                  Text('暂时只有这些哦亲~更多资讯正在路上')
                    .fontSize(12)
                    .fontColor($r('app.color.text_tertiary'))
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding({ top: 16, bottom: 8 })
                }
              }
              .width('100%')
              .height('100%')
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
            }
            .layoutWeight(1)
            .width('100%')
            .margin({ top: 20 })
            .onRefreshing(() => {
              this.refresh()
            })
          }
        } else if (this.selectedPlatform === 'music') {
          MusicHome({
            onSwitchPlatform: () => {
              this.selectedPlatform = ''
            }
          })
            .width('100%')
            .layoutWeight(1)
        } else {
          OtherHome({
            platformName: this.getPlatformName(this.selectedPlatform),
            onBack: () => {
              this.selectedPlatform = ''
            }
          })
            .width('100%')
            .layoutWeight(1)
        }
      }

    }
    .width("100%")
    .height("100%")
    .backgroundColor($r('app.color.page_bg'))
    .padding({
      left: 20,
      right: 20,
      top: this.topHeight,
      bottom: 20
    })
  }
}

class HDMModifier extends AttributeUpdater<NavigationAttribute> {
  // instance 其实就是HMRouter 包裹的那一层Navigation的对象实例
  initializeModifier(instance: NavigationAttribute): void {
    instance.titleMode(NavigationTitleMode.Mini) // mini模式
    // 分栏模式
    instance.mode(NavigationMode.Stack) // 去掉分栏模式
    // 隐藏模式的标题栏
    instance.hideTitleBar(true) // 隐藏标题栏
  }
}
