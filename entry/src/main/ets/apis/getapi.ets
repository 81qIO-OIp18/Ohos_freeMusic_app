import { HMRequest, HTTP_PATH } from "library";
import { MusicPlaylistRespData, SongDetail } from "../viewmodles/commons";


/**
 * 搜索歌曲列表（format=json）
 * @param ss 歌曲名或歌手名
 * 返回 data 内层结构：{ total_available, requested, returned, songs: [{index, name, artists}] }
 */
export const MUSIC_free_list_API =
  (ss: string): Promise<MusicPlaylistRespData> =>
  HMRequest.get<MusicPlaylistRespData>(HTTP_PATH.MUSIC_FREE_URL, { "ss": ss, "format": 'json' })

/**
 * 获取单首歌曲详情（播放地址、封面、歌词、时长）
 * @param ss 搜索关键词
 * @param n  歌曲序号（从搜索结果的 index 取）
 */
export const MUSIC_free_API =
  (ss: string, n: number): Promise<SongDetail> =>
  HMRequest.get<SongDetail>(HTTP_PATH.MUSIC_FREE_URL, { "ss": ss, "n": n.toString(), "format": 'json' })
