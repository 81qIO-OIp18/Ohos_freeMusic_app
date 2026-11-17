export class GlobalVariable {
  static readonly SAFE_TOP_HEIGHT: string = "topHeight" // 顶部安全区的key
  static readonly SAFE_BOTTOM_HEIGHT: string = "bottomHeight" // 顶部安全区的key
  static readonly TAB_BAR_HIDE: string = "tabBarHide" // 是否隐藏底部TabBar
  static readonly MAIN_PAGE_ID: string = "main_navigation" // 主容器的标识
  static readonly MAIN_PAGE: string = "main_page" // 主页地址
}

// 所有的请求地址
export class HTTP_PATH {
  // static readonly HOME_CATEGORY: string = "question/type" // 请求分类的地址
  static readonly MUSIC_FREE_URL: string = "https://api.luosu.top/api/kgmusic"
}

// 所有的页面地址(只记录不引用，方便后续查找每个页面)
export class PAGE_PATH {
  static readonly SEARCH_PAGE: string = "search_view" // 搜索页面
}
