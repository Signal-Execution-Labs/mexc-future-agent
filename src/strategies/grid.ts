import type { Strategy, StrategyContext } from "./types";
import type { StrategySignal } from "../types";

const GRID_LEVELS = 5;
const GRID_SPACING_PCT = 0.4;

export function gridLevels(center: number): number[] {
  const levels: number[] = [];
  for (let i = -Math.floor(GRID_LEVELS / 2); i <= Math.floor(GRID_LEVELS / 2); i++) {
    if (i === 0) continue;
    levels.push(center * (1 + (i * GRID_SPACING_PCT) / 100));
  }
  return levels.sort((a, b) => a - b);
}

export const gridStrategy: Strategy = {
  name: "grid",
  evaluate(ctx: StrategyContext): StrategySignal {
    const levels = gridLevels(ctx.lastPrice);
    const below = levels.filter((l) => l < ctx.lastPrice);
    const above = levels.filter((l) => l > ctx.lastPrice);
    const nearestBelow = below[below.length - 1];
    const nearestAbove = above[0];
    const hasPos = ctx.positions.length > 0;

    if (!hasPos && nearestBelow && ctx.lastPrice <= nearestBelow * 1.001) {
      return { action: "open_long", reason: `grid buy near ${nearestBelow.toFixed(2)}` };
    }
    if (hasPos && nearestAbove && ctx.lastPrice >= nearestAbove * 0.999) {
      return { action: "close", reason: `grid take profit near ${nearestAbove.toFixed(2)}` };
    }
    return { action: "hold", reason: "grid idle" };
  },
};
