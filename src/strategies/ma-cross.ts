import { sma } from "../indicators/sma";
import { rsi } from "../indicators/rsi";
import type { Strategy, StrategyContext } from "./types";
import type { StrategySignal } from "../types";

const FAST = 9;
const SLOW = 21;
const RSI_LOW = 35;
const RSI_HIGH = 65;

export const maCrossStrategy: Strategy = {
  name: "ma-cross",
  evaluate(ctx: StrategyContext): StrategySignal {
    const closes = ctx.klines.map((k) => k.close);
    if (closes.length < SLOW + 2) {
      return { action: "hold", reason: "insufficient klines" };
    }
    const fast = sma(closes, FAST);
    const slow = sma(closes, SLOW);
    const rs = rsi(closes, 14);
    const f = fast[fast.length - 1];
    const s = slow[slow.length - 1];
    const prevF = fast[fast.length - 2];
    const prevS = slow[slow.length - 2];
    const r = rs[rs.length - 1] ?? 50;
    const hasLong = ctx.positions.some((p) => p.positionType === 1);
    const hasShort = ctx.positions.some((p) => p.positionType === 2);

    if (prevF <= prevS && f > s && r < RSI_HIGH && !hasLong) {
      return { action: "open_long", reason: "fast MA crossed above slow", strength: f - s };
    }
    if (prevF >= prevS && f < s && r > RSI_LOW && !hasShort) {
      return { action: "open_short", reason: "fast MA crossed below slow", strength: s - f };
    }
    if (hasLong && f < s) return { action: "close", reason: "exit long on bear cross" };
    if (hasShort && f > s) return { action: "close", reason: "exit short on bull cross" };
    return { action: "hold", reason: "no signal" };
  },
};
