import { Log } from '@abner/log'

//日志打印工具
Log.init({
  tag: "｡･ﾟﾟ･(>д<)･ﾟﾟ･｡",
  domain: 0x0000,
  close: false,
  isHilog: true,
  showLogLocation: true,
  logSize: 800
})

export { Log as print } //按需导出
