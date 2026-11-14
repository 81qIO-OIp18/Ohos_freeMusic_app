/**
 * 节流：interval 毫秒内最多放行一次（常用于频繁触发的刷新/滚动场景）
 */
export class Throttle {
  private interval: number
  private lastTime: number = 0

  constructor(interval: number = 1000) {
    this.interval = interval
  }

  // 返回 true 表示本次允许执行
  canRun(): boolean {
    const now: number = Date.now()
    if (now - this.lastTime < this.interval) {
      return false
    }
    this.lastTime = now
    return true
  }
}

/**
 * 防抖：wait 毫秒内的多次触发只执行最后一次（常用于点击/输入场景）
 */
export class Debounce {
  private wait: number
  private timer: number = -1

  constructor(wait: number = 500) {
    this.wait = wait
  }

  run(action: () => void): void {
    if (this.timer !== -1) {
      clearTimeout(this.timer)
    }
    this.timer = setTimeout(() => {
      this.timer = -1
      action()
    }, this.wait)
  }
}
