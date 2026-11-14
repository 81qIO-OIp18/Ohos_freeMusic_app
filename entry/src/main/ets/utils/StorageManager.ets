import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'

const TAG = 'StorageManager'
const STORE_NAME = 'music_store'

export class StorageManager {
  private static prefs: preferences.Preferences | null = null

  static init(context: common.UIAbilityContext): Promise<void> {
    return new Promise((resolve, reject) => {
      preferences.getPreferences(context, STORE_NAME).then((prefs) => {
        StorageManager.prefs = prefs
        resolve()
      }).catch((e: string) => {
        console.error(TAG, 'init failed:', JSON.stringify(e))
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
    try {
      const prefs = StorageManager.ensureInit()
      const raw = prefs.getSync(key, '[]') as string
      const arr: string[] = JSON.parse(raw)
      return Array.isArray(arr) ? arr : []
    } catch (e) {
      console.error(TAG, 'getStringArray error:', JSON.stringify(e))
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
