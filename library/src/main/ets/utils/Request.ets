//网络请求工具
import axios, { AxiosError, AxiosResponse, InternalAxiosRequestConfig } from '@ohos/axios';
import { ResponseData } from '../viewmodels';
import { promptAction } from '@kit.ArkUI';


export const Base_Url: string = ""

/** 统一成功码：各上游接口成功码不统一，集中维护 */
const SUCCESS_CODES: number[] = [10000, 1, 200]
/** 请求超时时间（毫秒）：境外 API 响应较慢，保留较长等待 */
const REQUEST_TIMEOUT: number = 1000000

const instance = axios.create({
  baseURL: Base_Url, // 请求基础地址
  timeout: REQUEST_TIMEOUT
})
// 发送数据之前 夹带一丝私货
// 注册请求拦截器1.成功 2.失败
instance.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  // 我要给服务器发送数据 我想在发送过程中夹带一些私货
  // config 针对数据进行一些改变或者操作
  return config
}, (error: AxiosError) => {
  // 就让她失败
  // 把error传进入 告诉失败的原因
  return Promise.reject(error) // 返回失败
})

// 数据返回之后
// 注册响应拦截器 1.成功 2.失败
instance.interceptors.response.use((response: AxiosResponse) => {
  // 这个函数要求返回 必须是AxiosResponse类型
  // response.data 才是我们要的数据
  // return response.data.data
  // http状态
  // 业务状态
  const res = response.data as ResponseData // 定义数据
  // 兼容多种成功码：10000、1、200 等
  if (SUCCESS_CODES.includes(res.code)) {
    return response.data.data // 这里注意：不能用 res.data 返回
  }
  // 业务失败：提示用户
  try {
    promptAction.showToast({ message: res.message })
  } catch (e) {
    // 非 UI 上下文（如启动阶段）调用 toast 会抛异常，忽略提示即可
  }
  return Promise.reject(new Error(res.message))
}, (error: AxiosError) => {
  // 就让她失败
  // 把error传进入 告诉失败的原因
  return Promise.reject(error) // 返回失败
})


// 直接使用axios 相当于自己把axios的全局的基础地址定死了

// axios.defaults.baseURL = "www.baidu.com"
// 这样写 相当于所有人都只能用百度的基础地址

export class HMRequest {
  // get请求只能发送get参数/query参数/查询参数/地址栏参数
  static get<T>(url: string, params?: Record<string, Object>) {
    return instance.get<null, T>(url, { params })
  }

  // 请求体参数
  static post<T>(url: string, data?: Record<string, Object>) {
    return instance.post<null, T>(url, data)
  }

  static put<T>(url: string, data?: Record<string, Object>) {
    return instance.put<null, T>(url, data)
  }

  static delete<T>(url: string, params?: Record<string, Object>) {
    return instance.delete<null, T>(url, { params })
  }

  //get 查询
  // post 新增
  // delete 删除
  // put 修改
}