/**
 * 游戏项
 */
export interface GameItem {
  title: string;
  id: string;
  namespace: string;
  desc: string;
  seller: Seller;
  status: number;
  start_time: string;
  end_time: string;
}

/**
 * 厂商信息
 */
export interface Seller {
  id: string;
  name: string;
}

/**
 * 接口返回外层结构
 */
export interface GameListResp {
  code: number;
  message: string;
  data: GameItem[];
}
