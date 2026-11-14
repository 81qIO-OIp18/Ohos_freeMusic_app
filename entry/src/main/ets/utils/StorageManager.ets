import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'

const TAG = 'StorageManager'
const STORE_NAME = 'music_store'

export class StorageManager {
  private static prefs: preferences.Preferences | null = null

  static init(context: common.UIAbilityContext): Promise<void> {
    return new Promise((resolve, reject) => {
      preferences.getPreferences(context, STORE_NAME).then((prefs) => {
        StorageManager.prefs = prefs
        resolve()
      }).catch((e: BusinessError) => {
        console.error(TAG, 'init failed:', JSON.stringify(e))
        // 必须向外抛错，否则 Promise 永久挂起，启动流程会卡在 then 之前
        reject(new Error('StorageManager init failed'))
      })
    })
  }

  private static ensureInit(): preferences.Preferences {
    if (!StorageManager.prefs) {
      throw new Error('StorageManager not initialized')
    }
    return StorageManager.prefs
  }

  static getStringArray(key: string): string[] {
    let raw: string = '[]'
    try {
      const prefs = StorageManager.ensureInit()
      raw = prefs.getSync(key, '[]') as string
    } catch (e) {
      console.error(TAG, 'getStringArray read error:', JSON.stringify(e))
      return []
    }
    try {
      const arr: string[] = JSON.parse(raw) as string[]
      return Array.isArray(arr) ? arr : []
    } catch (e) {
      // 历史脏数据解析失败时降级为空数组，并清掉脏值
      console.error(TAG, 'getStringArray parse error:', JSON.stringify(e))
      return []
    }
  }

  static putStringArray(key: string, arr: string[]): void {
    try {
      const prefs = StorageManager.ensureInit()
      prefs.putSync(key, JSON.stringify(arr))
      prefs.flushSync()
    } catch (e) {
      console.error(TAG, 'putStringArray error:', JSON.stringify(e))
    }
  }
}
