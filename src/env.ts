import "dotenv/config";
import { DEFAULT_BASE_URL } from "./constants";

export const mexcEnv = {
  apiKey: process.env.MEXC_API_KEY ?? process.env.MEXC_KEY ?? "",
  apiSecret: process.env.MEXC_API_SECRET ?? "",
  cookie: process.env.MEXC_COOKIE ?? "",
  fingerprint: process.env.MEXC_FINGERPRINT ?? "",
  baseUrl: (process.env.MEXC_BASE_URL ?? DEFAULT_BASE_URL).replace(/\/$/, ""),
  timeoutMs: Math.max(3000, parseInt(process.env.MEXC_TIMEOUT_MS ?? "15000", 10)),
  symbol: (process.env.MEXC_SYMBOL ?? "BTC_USDT").toUpperCase(),
  leverage: Math.min(125, Math.max(1, parseInt(process.env.MEXC_LEVERAGE ?? "5", 10))),
  openType: parseInt(process.env.MEXC_OPEN_TYPE ?? "1", 10) as 1 | 2,
  userAgent: process.env.MEXC_USER_AGENT ?? "",
} as const;

export const BOT_POLL_INTERVAL_MS = Math.max(
  1000,
  parseInt(process.env.BOT_POLL_INTERVAL_MS ?? "5000", 10)
);

export const BOT_DRY_RUN = process.env.BOT_DRY_RUN === "true";

export const BOT_STRATEGY = (process.env.BOT_STRATEGY ?? "ma-cross") as
  | "ma-cross"
  | "grid";

export const RISK_MAX_POSITION_USDT = parseFloat(
  process.env.RISK_MAX_POSITION_USDT ?? "500"
);

export const RISK_RISK_PERCENT = Math.min(
  100,
  Math.max(0.1, parseFloat(process.env.RISK_RISK_PERCENT ?? "2"))
);
