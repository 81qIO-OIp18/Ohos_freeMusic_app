//网络请求工具
import axios, { AxiosError, AxiosResponse, InternalAxiosRequestConfig } from '@ohos/axios';
import { ResponseData } from '../viewmodels';
import { promptAction } from '@kit.ArkUI';


export const Base_Url: string = ""

const instance = axios.create({
  baseURL: Base_Url, // 请求基础地址
  timeout: 1000000 // 超时时间 10秒，境外API响应慢
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
  if (res.code === 10000 || res.code === 1 || res.code === 200) {
    // 此时说明请求成功
    return response.data.data // fullfiled // 这里注意： 不能用res.data返回

    // any类型 没有类型 any类型 any类型可以认为是任何类型
    // any类型可以认为是任意类型
  }
  // 一定失败了
  promptAction.showToast({ message: res.message }) // 提示消息
  return Promise.reject(new Error(res.message)) // pending fullfiled rejected
  // 假如新增一个用户- 接口调用成功了没有代码错误 业务没有成功
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