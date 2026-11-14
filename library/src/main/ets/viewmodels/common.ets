//数据类型接口
export interface UDItem {
  icon?: ResourceStr; // string | Resource
  activeIcon?: ResourceStr;
  name?: string;
  title?: string;
  Url?: string;
}

// 定义返回体类型
export interface ResponseData<T = object> {
  success: boolean
  code: number
  message: string
  data: T
}
