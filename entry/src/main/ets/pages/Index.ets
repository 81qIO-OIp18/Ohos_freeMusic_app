import { HMNavigation } from '@hadss/hmrouter'
import { AttributeUpdater } from '@kit.ArkUI'
import { GlobalVariable } from 'library'
import { MusicHome } from '../components/MusicHome'

@Entry
@Component
struct Index {
  modifier: HDMModifier = new HDMModifier() // 继承并实例化
  @StorageProp(GlobalVariable.SAFE_TOP_HEIGHT)
  topHeight: number = 0

  build() {
    Column() {
      HMNavigation({
        navigationId: GlobalVariable.MAIN_PAGE_ID, // 唯一的标识 通过这个标识可以拿到对象
        homePageUrl: GlobalVariable.MAIN_PAGE, // 通过这个地址可以回跳到主页 /main
        options: {
          modifier: this.modifier // 作用是什么？ Navigation组件的一些属性需要配置
        }
      }) {
        // 首页直接展示音乐首页
        MusicHome()
          .width('100%')
          .layoutWeight(1)
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
