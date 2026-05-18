import { RISK_MAX_POSITION_USDT } from "../env";
import type { OpenPosition, StrategySignal } from "../types";
import { rootLog } from "../logger";

export interface RiskDecision {
  allowed: boolean;
  reason: string;
}

export function validateSignal(
  signal: StrategySignal,
  positions: OpenPosition[],
  equityUsdt: number
): RiskDecision {
  if (signal.action === "hold") {
    return { allowed: true, reason: "hold" };
  }

  const exposure = positions.reduce(
    (sum, p) => sum + Math.abs(p.holdVol * p.holdAvgPrice),
    0
  );

  if (signal.action.startsWith("open") && exposure >= RISK_MAX_POSITION_USDT) {
    rootLog.warn("Risk block: max position notional reached");
    return { allowed: false, reason: "max position notional" };
  }

  if (equityUsdt < 10) {
    return { allowed: false, reason: "equity too low" };
  }

  return { allowed: true, reason: "ok" };
}
