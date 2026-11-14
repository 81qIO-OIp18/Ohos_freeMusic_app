// class  对象
import { window } from "@kit.ArkUI"
import { GlobalVariable } from "../constants"

// 导出一个对象
export class HMScreenManager {
  // 全屏方法
  ctx?: Context // 声明了一个属性

  // 获取窗口对象方法
  getWin() {
    return window.getLastWindow(this.ctx || getContext())
  }

  // 全屏方法
  async full() {
    const win = await this.getWin()
    win.setWindowLayoutFullScreen(true)
    this.setSafeAreaHeight(true) // 设置安全区高度
  }

  // 退出全屏方法
  async exitFull() {
    const win = await this.getWin()
    win.setWindowLayoutFullScreen(false)
    this.setSafeAreaHeight(false)
  }

  // 获取安全区高度 顶部高度 底部高度 设置到全局状态
  async setSafeAreaHeight(isFull: boolean) {
    if (isFull) {
      const win = await this.getWin()
      AppStorage.setOrCreate(GlobalVariable.SAFE_TOP_HEIGHT,
        px2vp(win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect.height))
      AppStorage.setOrCreate(GlobalVariable.SAFE_BOTTOM_HEIGHT,
        px2vp(win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect.height))

    } else {
      // 非全屏模式下 设置为0
      AppStorage.setOrCreate(GlobalVariable.SAFE_TOP_HEIGHT, 0)
      AppStorage.setOrCreate(GlobalVariable.SAFE_BOTTOM_HEIGHT, 0)
    }

  }
}

export const hmScreenManager = new HMScreenManager() // 导出一个单例

//使用测试

// import { GlobalVariable, HmLog, screenManager } from 'basic';
//
// @Entry
// @Component
// struct Index {
//   @StorageProp(GlobalVariable.SAFE_TOP_HEIGHT)
//   topHeight: number = 0
//
//   aboutToAppear(): void {
//     HmLog.log("我是老高")
//     HmLog.debug("我是老高")
//     HmLog.error("我是老高")
//     HmLog.warn("我是老高")
//     screenManager.fullScreen()
//   }
//
//   build() {
//     RelativeContainer() {
//       Text("测试")
//         .fontColor(Color.White)
//         .fontSize(40)
//     }
//     .height('100%')
//     .width('100%')
//     .backgroundColor(Color.Blue)
//     .padding({
//       top: this.topHeight
//     })
//   }
// }