/**
 * 免费音乐的接口返回结构
 */
export interface MusicPlaylistResp {
  code: number;
  message: string;
  data: MusicPlaylistRespData | null;
}

export interface MusicPlaylistRespData {
  total_available: number;
  requested: number;
  returned: number;
  songs: SongItem[];
}

export interface SongItem {
  index: number;
  name: string;
  artists: string;
}

// 首歌曲的详情
export  interface SongDetailResp {
  code: number;
  message: string;
  data: SongDetail;
}

export interface SongDetail {
  id: string;
  songmid: string;
  name: string;
  singer: string;
  album: string;
  duration: string;
  duration_sec: number;
  bitRate: number;
  fileSize: number;
  fileSize_str: string;
  extName: string;
  quality: string;
  quality_name: string;
  encodeType: string;
  cover_url: string;
  play_url: string;
  lyric: string;
  account: AccountInfo;
}

export interface AccountInfo {
  userid: string;
  nickname: string;
  vip_type: string;
}





