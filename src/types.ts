export type OrderSide = 1 | 2;
export type OpenType = 1 | 2;
export type OrderType = 1 | 2 | 3 | 4 | 5 | 6;

export interface MexcEnvelope<T> {
  success: boolean;
  code: number;
  message?: string;
  data?: T;
}

export interface ContractTicker {
  symbol: string;
  lastPrice: number;
  riseFallRate: number;
  volume24: number;
  fairPrice: number;
}

export interface KlineBar {
  time: number;
  open: number;
  high: number;
  low: number;
  close: number;
  vol: number;
}

export interface OpenPosition {
  positionId: number;
  symbol: string;
  holdVol: number;
  holdAvgPrice: number;
  openType: OpenType;
  positionType: 1 | 2;
  leverage: number;
  realised: number;
  unrealised: number;
}

export interface AccountAsset {
  currency: string;
  availableBalance: number;
  equity: number;
  unrealized: number;
}

export interface SubmitOrderParams {
  symbol: string;
  price: number;
  vol: number;
  side: OrderSide;
  type: OrderType;
  openType: OpenType;
  leverage: number;
  externalOid?: string;
}

export interface StrategySignal {
  action: "open_long" | "open_short" | "close" | "hold";
  reason: string;
  strength?: number;
}
