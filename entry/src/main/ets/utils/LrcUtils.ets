/**
 * LRC 格式歌词解析工具
 * 歌词格式示例：[00:21.98]青花瓷
 */

export interface LrcLine {
  /** 该行歌词起始时间（毫秒） */
  time: number
  /** 歌词文本 */
  text: string
}

const LRC_LINE_REGEX = /\[(\d{2,}):(\d{2})(?:[.:](\d{2,}))?\]/g

/**
 * 解析 LRC 格式歌词文本为带时间戳的行数组
 * @param lrcText LRC 原始文本
 */
export function parseLrc(lrcText: string): LrcLine[] {
  if (!lrcText) {
    return []
  }
  const lines: LrcLine[] = []
  const rawLines = lrcText.split(/\r?\n/)
  for (const raw of rawLines) {
    const matches = raw.match(LRC_LINE_REGEX)
    if (!matches) {
      continue
    }
    const text = raw.replace(LRC_LINE_REGEX, '').trim()
    if (!text) {
      continue
    }
    // 一行可能有多个时间戳（如 [00:12.00][00:34.00] 副歌）
    for (const ts of matches) {
      const m = ts.match(/\[(\d{2,}):(\d{2})(?:[.:](\d{2,}))?\]/)
      if (!m) {
        continue
      }
      const min = parseInt(m[1], 10)
      const sec = parseInt(m[2], 10)
      const msPart = m[3] ? parseInt(m[3], 10) : 0
      const time = (min * 60 + sec) * 1000 + msPart * (m[3] && m[3].length === 2 ? 10 : 1)
      lines.push({ time, text })
    }
  }
  lines.sort((a, b) => a.time - b.time)
  return lines
}

/**
 * 根据当前播放时间（毫秒）获取当前歌词行索引
 * @param lines 解析后的歌词行
 * @param currentMs 当前播放时间（毫秒）
 */
export function findLrcIndex(lines: LrcLine[], currentMs: number): number {
  if (lines.length === 0) {
    return -1
  }
  let idx = -1
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].time <= currentMs) {
      idx = i
    } else {
      break
    }
  }
  return idx
}

/**
 * 毫秒数格式化为 mm:ss（超过一小时显示 hh:mm:ss）
 */
export function fmtMs(ms: number): string {
  if (!ms || ms < 0) {
    return '00:00'
  }
  const totalSec = Math.floor(ms / 1000)
  const h = Math.floor(totalSec / 3600)
  const m = Math.floor((totalSec % 3600) / 60)
  const s = totalSec % 60
  const pad = (n: number) => n.toString().padStart(2, '0')
  return h > 0 ? `${pad(h)}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`
}
