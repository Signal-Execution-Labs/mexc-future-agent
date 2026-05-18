import type { AccountAsset } from "../types";
import { RISK_RISK_PERCENT, RISK_MAX_POSITION_USDT } from "../env";

export function computeOrderVolume(
  equityUsdt: number,
  price: number,
  contractSize: number,
  riskPercent = RISK_RISK_PERCENT
): number {
  if (price <= 0 || contractSize <= 0) return 0;
  const riskCapital = Math.min(
    equityUsdt * (riskPercent / 100),
    RISK_MAX_POSITION_USDT
  );
  const notional = riskCapital * 1;
  const vol = notional / (price * contractSize);
  return Math.max(1, Math.floor(vol));
}

export function pickUsdtEquity(assets: AccountAsset[]): number {
  const usdt = assets.find((a) => a.currency.toUpperCase() === "USDT");
  return usdt?.equity ?? usdt?.availableBalance ?? 0;
}
