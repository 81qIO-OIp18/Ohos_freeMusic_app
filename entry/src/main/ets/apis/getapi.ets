import { HMRequest, HTTP_PATH } from "library";
import { GameItem, MusicPlaylistRespData, SongDetail } from "../viewmodles/commons";

export const gerEPIC_free_game_API = (): Promise<GameItem[]> => HMRequest.get<GameItem[]>(HTTP_PATH.EPIC_FREE_GAME)

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

// 测试用假数据：status 1 = 可领取，0 = 即将开始；共 12 条，保证内容超出一屏便于测滑动
const MOCK_GAME_LIST: GameItem[] = [
  {
    title: '《Idle Champions of the Forgotten Realms》',
    id: 'a9748abde1c94b66aae5250bb9fc5503',
    namespace: '7e508f543b05465abe3a935960eb70ac',
    desc: '《Idle Champions》是一款官方《龙与地下城》策略管理游戏，聚集了来自小说、战役和剧集中的各路标志性角色，展开一场史诗级的冒险。',
    seller: { id: 'o-3kpjwtwqwfl2p9wdwvpad7yqz4kt6c', name: 'Codename Entertainment' },
    status: 1,
    start_time: '2026-11-06 00:00:00',
    end_time: '2026-11-13 00:00:00'
  },
  {
    title: '浮游世界',
    id: '3be0a0d8479946d78f60d90c9442a0b4',
    namespace: '27e33143fc9e4de8bbf76782292933d4',
    desc: '漂浮垃圾城生存游戏！从海洋表面尽可能搜集珍贵的垃圾，发展你的城市，同时努力在这个色彩斑斓的后末日世界中生存下去。',
    seller: { id: 'o-dwuld3yb6hujsr2eddx6flmag4yn8r', name: 'Pajama Llama Games' },
    status: 1,
    start_time: '2026-11-06 00:00:00',
    end_time: '2026-11-13 00:00:00'
  },
  {
    title: 'The Spirit and the Mouse',
    id: '5c1f0d2e8b7a4f6d9c3e2a1b0f8d7c6e',
    namespace: '6f4d2a1b8c7e4f3d9a5b2c8d1e7f6a4b',
    desc: '扮演一只小老鼠，在法国乡村的街道间穿梭，帮助当地居民化解烦恼，用善意点亮整座小镇。',
    seller: { id: 'o-1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p', name: 'Alblobs Studio' },
    status: 1,
    start_time: '2026-11-06 00:00:00',
    end_time: '2026-11-13 00:00:00'
  },
  {
    title: '斗阵骑士 Knightica',
    id: '9975548b6d404a94b8a9bdb34cad49e9',
    namespace: '02d659f31e1c43a78c43fd9fd9edc089',
    desc: '在这款类Rogue自走棋游戏中，征招强大单位，悉心排兵布阵，调整策略，充分发掘军队的协同效果！',
    seller: { id: 'o-7jby5x5ez3xmyf5qhgur72hlye379e', name: 'Goblinz Studio SAS' },
    status: 0,
    start_time: '2026-11-13 00:00:00',
    end_time: '2026-11-20 00:00:00'
  },
  {
    title: 'Ghostwire: Tokyo',
    id: '8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b',
    namespace: '3b2a1c4d5e6f7a8b9c0d1e2f3a4b5c6d',
    desc: '在空无一人的东京街头，运用强大的灵魂能力对抗超自然力量，揭开居民神秘失踪背后的真相。',
    seller: { id: 'o-9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d', name: 'Tango Gameworks' },
    status: 0,
    start_time: '2026-11-13 00:00:00',
    end_time: '2026-11-20 00:00:00'
  },
  {
    title: 'A Plague Tale: Innocence',
    id: 'mock-plague-tale-001',
    namespace: 'mock-ns-plague-tale-001',
    desc: '跟随阿米西亚和弟弟雨果的脚步，在瘟疫肆虐、鼠群横行的中世纪法国挣扎求生，寻找改变命运的答案。',
    seller: { id: 'mock-seller-asobo', name: 'Asobo Studio' },
    status: 0,
    start_time: '2026-11-13 00:00:00',
    end_time: '2026-11-20 00:00:00'
  },
  {
    title: 'Maneater',
    id: 'mock-maneater-002',
    namespace: 'mock-ns-maneater-002',
    desc: '扮演一条从幼鲨成长为顶级掠食者的鲨鱼，在开放海域中捕食、进化，并向毁掉你生活的人类复仇。',
    seller: { id: 'mock-seller-tripwire', name: 'Tripwire Interactive' },
    status: 0,
    start_time: '2026-11-13 00:00:00',
    end_time: '2026-11-20 00:00:00'
  },
  {
    title: 'Sable',
    id: 'mock-sable-003',
    namespace: 'mock-ns-sable-003',
    desc: '骑上悬浮摩托穿越广袤的沙漠，探索古老遗迹与奇特地貌，在属于你自己的成长旅程中寻找自我。',
    seller: { id: 'mock-seller-shedworks', name: 'Shedworks' },
    status: 0,
    start_time: '2026-11-13 00:00:00',
    end_time: '2026-11-20 00:00:00'
  },
  {
    title: 'Dead by Daylight',
    id: 'mock-dbd-004',
    namespace: 'mock-ns-dbd-004',
    desc: '非对称多人恐怖游戏：一名杀手对抗四名逃生者，在黑暗的迷雾中上演紧张刺激的追逐与躲藏。',
    seller: { id: 'mock-seller-behaviour', name: 'Behaviour Interactive' },
    status: 0,
    start_time: '2026-11-13 00:00:00',
    end_time: '2026-11-20 00:00:00'
  },
  {
    title: 'Borderlands 3',
    id: 'mock-borderlands3-005',
    namespace: 'mock-ns-borderlands3-005',
    desc: '拿起海量混乱风格的枪械，与好友一起踏上寻宝之旅，在多个星球上对抗疯狂的敌人与财团势力。',
    seller: { id: 'mock-seller-gearbox', name: 'Gearbox Software' },
    status: 0,
    start_time: '2026-11-13 00:00:00',
    end_time: '2026-11-20 00:00:00'
  },
  {
    title: 'Saints Row',
    id: 'mock-saintsrow-006',
    namespace: 'mock-ns-saintsrow-006',
    desc: '在充满活力的城市中白手起家，组建属于你的帮派，用最夸张的方式对抗敌对势力，打造自己的帝国。',
    seller: { id: 'mock-seller-deepsilver', name: 'Deep Silver' },
    status: 0,
    start_time: '2026-11-13 00:00:00',
    end_time: '2026-11-20 00:00:00'
  },
  {
    title: '光明记忆：无限',
    id: 'mock-brightmemory-007',
    namespace: 'mock-ns-brightmemory-007',
    desc: '操控高速位移与近战射击的独特战斗方式，在充满未来感的场景中对抗神秘组织，揭开世界崩坏的真相。',
    seller: { id: 'mock-seller-fyqd', name: '飞燕群岛工作室' },
    status: 0,
    start_time: '2026-11-13 00:00:00',
    end_time: '2026-11-20 00:00:00'
  }
]

// 假数据接口，带 1.5 秒延时模拟网络加载
export const gerEPIC_free_game_MOCK_API = (): Promise<GameItem[]> => {
  return new Promise<GameItem[]>((resolve) => {
    setTimeout(() => resolve(MOCK_GAME_LIST), 1500)
  })
}
