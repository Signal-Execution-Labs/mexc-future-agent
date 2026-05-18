import type { KlineBar, OpenPosition, StrategySignal } from "../types";

export interface StrategyContext {
  symbol: string;
  klines: KlineBar[];
  positions: OpenPosition[];
  lastPrice: number;
}

export interface Strategy {
  name: string;
  evaluate(ctx: StrategyContext): StrategySignal;
}
