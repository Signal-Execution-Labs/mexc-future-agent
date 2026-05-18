#!/usr/bin/env bash
# Builds mexc-future-trading-bot with one git commit per step (35+ commits).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

commit() {
  git add -A
  git commit -m "$1" --allow-empty 2>/dev/null || git commit -m "$1"
}

if [[ ! -d .git ]]; then
  git init -b main
fi

mkdir -p src/http src/api src/risk src/indicators src/strategies src/bot docs

# 1
cat > package.json <<'EOF'
{
  "name": "mexc-future-trading-bot",
  "version": "1.0.0",
  "description": "TypeScript CLI for automated MEXC USDT-margined perpetual futures strategies with risk controls.",
  "main": "dist/bot-run.js",
  "license": "MIT",
  "keywords": ["mexc", "futures", "perpetual", "trading-bot", "typescript"],
  "scripts": {
    "bot": "tsx src/bot-run.ts",
    "build": "tsc",
    "typecheck": "tsc --noEmit",
    "check": "npm run typecheck"
  },
  "engines": { "node": ">=20" }
}
EOF
commit "chore: initialize package.json with project metadata"

# 2
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2021",
    "module": "CommonJS",
    "rootDir": "src",
    "outDir": "dist",
    "moduleResolution": "node",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "sourceMap": true,
    "resolveJsonModule": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
EOF
commit "chore: add TypeScript compiler configuration"

# 3
cat > .gitignore <<'EOF'
node_modules/
dist/
.env
*.log
.DS_Store
EOF
commit "chore: add gitignore for Node artifacts and secrets"

# 4
mkdir -p src
cat > src/constants.ts <<'EOF'
export const SERVICE_NAME = "mexc-future-trading-bot";
export const VERSION = "1.0.0";
export const DEFAULT_BASE_URL = "https://contract.mexc.com";
export const DEFAULT_USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
EOF
commit "feat: add service constants and default MEXC contract base URL"

# 5
cat > src/types.ts <<'EOF'
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
EOF
commit "feat: add core domain types for orders positions and signals"

# 6
cat > src/mexc-error.ts <<'EOF'
export class MexcError extends Error {
  readonly code?: number;
  readonly status?: number;
  readonly bodySnippet?: string;

  constructor(
    message: string,
    opts: { code?: number; status?: number; bodySnippet?: string } = {}
  ) {
    super(message);
    this.name = "MexcError";
    this.code = opts.code;
    this.status = opts.status;
    this.bodySnippet = opts.bodySnippet;
  }
}
EOF
commit "feat: add MexcError typed HTTP failure wrapper"

# 7
cat > src/env.ts <<'EOF'
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
EOF
commit "feat: load MEXC credentials symbol leverage and bot knobs from env"

# 8
cat > src/logger.ts <<'EOF'
import { VERSION, SERVICE_NAME } from "./constants";

export interface Logger {
  info(...args: unknown[]): void;
  warn(...args: unknown[]): void;
  error(...args: unknown[]): void;
  debug(...args: unknown[]): void;
}

export const rootLog: Logger = {
  info: (...a) => console.log("[info]", ...a),
  warn: (...a) => console.warn("[warn]", ...a),
  error: (...a) => console.error("[error]", ...a),
  debug: (...a) => {
    if (process.env.LOG_DEBUG === "true") console.debug("[debug]", ...a);
  },
};

export function logVersion(): void {
  rootLog.info(`${SERVICE_NAME} v${VERSION}`);
}
EOF
commit "feat: expose console Logger for structured downstream swaps"

# 9
cat > src/backoff.ts <<'EOF'
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function withBackoff<T>(
  fn: () => Promise<T>,
  opts: { retries?: number; baseMs?: number } = {}
): Promise<T> {
  const retries = opts.retries ?? 3;
  const baseMs = opts.baseMs ?? 500;
  let last: unknown;
  for (let i = 0; i <= retries; i++) {
    try {
      return await fn();
    } catch (e) {
      last = e;
      if (i === retries) break;
      await sleep(baseMs * 2 ** i);
    }
  }
  throw last;
}
EOF
commit "feat: exponential backoff primitive for flaky REST responses"

# 10
cat > src/signals.ts <<'EOF'
let shuttingDown = false;

export function installShutdownHandlers(onShutdown: () => void): void {
  const handler = () => {
    if (shuttingDown) return;
    shuttingDown = true;
    onShutdown();
  };
  process.on("SIGINT", handler);
  process.on("SIGTERM", handler);
}

export function isShuttingDown(): boolean {
  return shuttingDown;
}
EOF
commit "feat: graceful shutdown hooks for strategy polling loop"

# 11
cat > src/credentials.ts <<'EOF'
import { mexcEnv } from "./env";

export function assertMexcCredentials(): void {
  const hasOpenApi =
    mexcEnv.apiKey.trim() !== "" && mexcEnv.apiSecret.trim() !== "";
  const hasWebSession =
    mexcEnv.apiKey.trim() !== "" || mexcEnv.cookie.trim() !== "";
  if (!hasOpenApi && !hasWebSession) {
    throw new Error(
      "Set MEXC_API_KEY + MEXC_API_SECRET (Open API) or MEXC_KEY/MEXC_COOKIE (web session)."
    );
  }
}

export function usesOpenApiAuth(): boolean {
  return mexcEnv.apiKey.trim() !== "" && mexcEnv.apiSecret.trim() !== "";
}
EOF
commit "feat: credential guards for Open API versus web session auth"

# 12
cat > src/http/decode-body.ts <<'EOF'
import { brotliDecompressSync, gunzipSync, inflateRawSync, inflateSync } from "node:zlib";

export function decodeBody(buf: Buffer, encoding: string | undefined): string {
  if (!buf.length) return "";
  const enc = (encoding || "").toLowerCase().trim();
  try {
    if (enc === "gzip" || enc === "x-gzip") return gunzipSync(buf).toString("utf8");
    if (enc === "br") return brotliDecompressSync(buf).toString("utf8");
    if (enc === "deflate") {
      try {
        return inflateSync(buf).toString("utf8");
      } catch {
        return inflateRawSync(buf).toString("utf8");
      }
    }
  } catch {
    /* fall through */
  }
  return buf.toString("utf8");
}

export function firstHeader(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}
EOF
commit "feat: add gzip and brotli response body decoder"

# 13
cat > src/http/headers.ts <<'EOF'
import { createHmac } from "node:crypto";
import { DEFAULT_USER_AGENT } from "../constants";
import { mexcEnv } from "../env";
import { usesOpenApiAuth } from "../credentials";

export function buildWebHeaders(contentType?: string): Record<string, string> {
  const headers: Record<string, string> = {
    Authorization: mexcEnv.apiKey,
    "User-Agent": mexcEnv.userAgent || DEFAULT_USER_AGENT,
    Accept: "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    Origin: "https://futures.mexc.com",
    Referer: "https://futures.mexc.com/exchange",
    Language: "English",
  };
  if (contentType) headers["Content-Type"] = contentType;
  if (mexcEnv.cookie) headers.Cookie = mexcEnv.cookie;
  if (mexcEnv.fingerprint) headers["x-mxc-fingerprint"] = mexcEnv.fingerprint;
  return headers;
}

export function signOpenApi(
  method: string,
  path: string,
  queryOrBody: string,
  timestamp: string
): Record<string, string> {
  const target = mexcEnv.apiKey + timestamp + queryOrBody;
  const signature = createHmac("sha256", mexcEnv.apiSecret)
    .update(target)
    .digest("hex");
  return {
    "ApiKey": mexcEnv.apiKey,
    "Request-Time": timestamp,
    Signature: signature,
    "Content-Type": "application/json",
  };
}

export function buildRequestHeaders(
  method: string,
  path: string,
  body?: string
): Record<string, string> {
  if (usesOpenApiAuth()) {
    const ts = Date.now().toString();
    const signed = signOpenApi(method, path, body ?? "", ts);
    return { ...signed, "User-Agent": mexcEnv.userAgent || DEFAULT_USER_AGENT };
  }
  return buildWebHeaders(body ? "application/json" : undefined);
}
EOF
commit "feat: add MEXC web session and Open API HMAC header builders"

# 14
cat > src/http/proxy.ts <<'EOF'
import { Buffer } from "node:buffer";
import { ProxyAgent, type Dispatcher } from "undici";

export interface ProxyConfig {
  url: string;
  username?: string;
  password?: string;
}

export function buildProxyDispatcher(proxy?: ProxyConfig): Dispatcher | undefined {
  if (!proxy?.url) return undefined;
  const token =
    proxy.username && proxy.password
      ? Buffer.from(`${proxy.username}:${proxy.password}`).toString("base64")
      : undefined;
  return new ProxyAgent({
    uri: proxy.url,
    ...(token ? { token: `Basic ${token}` } : {}),
  });
}

export function proxyFromEnv(): ProxyConfig | undefined {
  if (process.env.MEXC_PROXY_ENABLED !== "true") return undefined;
  const url = process.env.MEXC_PROXY_URL;
  if (!url) return undefined;
  return {
    url,
    username: process.env.MEXC_PROXY_USERNAME,
    password: process.env.MEXC_PROXY_PASSWORD,
  };
}
EOF
commit "feat: add optional HTTP proxy dispatcher factory"

# 15
cat > src/http/mexc-http.ts <<'EOF'
import { Buffer } from "node:buffer";
import { request } from "undici";
import { mexcEnv } from "../env";
import { MexcError } from "../mexc-error";
import type { MexcEnvelope } from "../types";
import { decodeBody, firstHeader } from "./decode-body";
import { buildRequestHeaders } from "./headers";
import { buildProxyDispatcher, proxyFromEnv } from "./proxy";

export async function mexcRequest<T>(
  method: "GET" | "POST" | "DELETE",
  path: string,
  body?: Record<string, unknown>
): Promise<T> {
  const query = method === "GET" && body
    ? "?" + new URLSearchParams(
        Object.entries(body).map(([k, v]) => [k, String(v)])
      ).toString()
    : "";
  const url = `${mexcEnv.baseUrl}${path}${query}`;
  const bodyStr = method !== "GET" && body ? JSON.stringify(body) : undefined;
  const headers = buildRequestHeaders(method, path, bodyStr);
  const dispatcher = buildProxyDispatcher(proxyFromEnv());

  let response;
  try {
    response = await request(url, {
      method,
      headers,
      body: bodyStr,
      headersTimeout: mexcEnv.timeoutMs,
      bodyTimeout: mexcEnv.timeoutMs,
      ...(dispatcher ? { dispatcher } : {}),
    });
  } catch (err) {
    const cause = err instanceof Error ? err.message : String(err);
    throw new MexcError(`Network error contacting MEXC: ${cause}`);
  }

  const raw = Buffer.from(await response.body.arrayBuffer());
  const text = decodeBody(raw, firstHeader(response.headers["content-encoding"]));

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw new MexcError(`HTTP ${response.statusCode} from MEXC`, {
      status: response.statusCode,
      bodySnippet: text.slice(0, 500),
    });
  }

  let payload: MexcEnvelope<T>;
  try {
    payload = JSON.parse(text) as MexcEnvelope<T>;
  } catch {
    throw new MexcError("Failed to parse MEXC JSON", {
      status: response.statusCode,
      bodySnippet: text.slice(0, 500),
    });
  }

  if (!payload.success) {
    throw new MexcError(payload.message || "MEXC success=false", {
      code: payload.code,
      status: response.statusCode,
      bodySnippet: text.slice(0, 500),
    });
  }

  return payload.data as T;
}
EOF
commit "feat: add low-level MexcHttp client with timeout and envelope parsing"

# 16
cat > src/api/market.ts <<'EOF'
import { mexcRequest } from "../http/mexc-http";
import type { ContractTicker, KlineBar } from "../types";

export async function fetchTicker(symbol: string): Promise<ContractTicker> {
  const data = await mexcRequest<ContractTicker>("GET", `/api/v1/contract/ticker`, {
    symbol,
  });
  return data;
}

export async function fetchKlines(
  symbol: string,
  interval: string,
  limit: number
): Promise<KlineBar[]> {
  const rows = await mexcRequest<number[][]>("GET", `/api/v1/contract/kline/${symbol}`, {
    interval,
    limit,
  });
  return (rows ?? []).map((r) => ({
    time: r[0],
    open: r[1],
    close: r[2],
    high: r[3],
    low: r[4],
    vol: r[5],
  }));
}
EOF
commit "feat: implement contract ticker and kline market data endpoints"

# 17
cat > src/api/account.ts <<'EOF'
import { mexcRequest } from "../http/mexc-http";
import type { AccountAsset } from "../types";

export async function fetchAccountAssets(): Promise<AccountAsset[]> {
  return mexcRequest<AccountAsset[]>("GET", "/api/v1/private/account/assets");
}
EOF
commit "feat: implement fetchAccountAssets private endpoint wrapper"

# 18
cat > src/api/positions.ts <<'EOF'
import { mexcRequest } from "../http/mexc-http";
import type { OpenPosition } from "../types";

export async function fetchOpenPositions(symbol?: string): Promise<OpenPosition[]> {
  const params = symbol ? { symbol } : undefined;
  return mexcRequest<OpenPosition[]>(
    "GET",
    "/api/v1/private/position/open_positions",
    params
  );
}
EOF
commit "feat: implement fetchOpenPositions for symbol scoped hedges"

# 19
cat > src/api/orders.ts <<'EOF'
import { mexcRequest } from "../http/mexc-http";
import type { SubmitOrderParams } from "../types";

export interface OrderAck {
  orderId: string;
}

export async function submitOrder(params: SubmitOrderParams): Promise<OrderAck> {
  return mexcRequest<OrderAck>("POST", "/api/v1/private/order/submit", {
    symbol: params.symbol,
    price: params.price,
    vol: params.vol,
    side: params.side,
    type: params.type,
    openType: params.openType,
    leverage: params.leverage,
    externalOid: params.externalOid ?? `bot-${Date.now()}`,
  });
}

export async function cancelOrder(orderId: string): Promise<void> {
  await mexcRequest<null>("POST", "/api/v1/private/order/cancel", { orderId });
}

export async function cancelAllOrders(symbol: string): Promise<void> {
  await mexcRequest<null>("POST", "/api/v1/private/order/cancel_all", { symbol });
}
EOF
commit "feat: implement submit cancel and cancel-all order endpoints"

# 20
cat > src/api/leverage.ts <<'EOF'
import { mexcRequest } from "../http/mexc-http";

export async function setLeverage(
  symbol: string,
  leverage: number,
  openType: 1 | 2
): Promise<void> {
  await mexcRequest<null>("POST", "/api/v1/private/position/change_leverage", {
    symbol,
    leverage,
    openType,
  });
}
EOF
commit "feat: implement setLeverage position configuration wrapper"

# 21
cat > src/risk/position-size.ts <<'EOF'
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
EOF
commit "feat: add position sizing helper from equity risk percent caps"

# 22
cat > src/indicators/sma.ts <<'EOF'
export function sma(values: number[], period: number): number[] {
  if (period < 1 || values.length < period) return [];
  const out: number[] = [];
  let sum = 0;
  for (let i = 0; i < values.length; i++) {
    sum += values[i];
    if (i >= period) sum -= values[i - period];
    if (i >= period - 1) out.push(sum / period);
  }
  return out;
}
EOF
commit "feat: add simple moving average indicator utility"

# 23
cat > src/indicators/rsi.ts <<'EOF'
export function rsi(closes: number[], period = 14): number[] {
  if (closes.length < period + 1) return [];
  const out: number[] = [];
  let gains = 0;
  let losses = 0;
  for (let i = 1; i <= period; i++) {
    const d = closes[i] - closes[i - 1];
    if (d >= 0) gains += d;
    else losses -= d;
  }
  let avgGain = gains / period;
  let avgLoss = losses / period;
  out.push(100 - 100 / (1 + (avgLoss === 0 ? 100 : avgGain / avgLoss)));
  for (let i = period + 1; i < closes.length; i++) {
    const d = closes[i] - closes[i - 1];
    const gain = d > 0 ? d : 0;
    const loss = d < 0 ? -d : 0;
    avgGain = (avgGain * (period - 1) + gain) / period;
    avgLoss = (avgLoss * (period - 1) + loss) / period;
    const rs = avgLoss === 0 ? 100 : avgGain / avgLoss;
    out.push(100 - 100 / (1 + rs));
  }
  return out;
}
EOF
commit "feat: add RSI indicator for overbought oversold filters"

# 24
cat > src/strategies/types.ts <<'EOF'
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
EOF
commit "feat: define Strategy interface and evaluation context"

# 25
cat > src/strategies/ma-cross.ts <<'EOF'
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
EOF
commit "feat: add MaCrossStrategy with RSI filter and cross exits"

# 26
cat > src/strategies/grid.ts <<'EOF'
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
EOF
commit "feat: add GridStrategy level planner with spacing bands"

# 27
cat > src/risk/manager.ts <<'EOF'
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
EOF
commit "feat: add RiskManager max notional and minimum equity gates"

# 28
cat > src/bot/executor.ts <<'EOF'
import { submitOrder, cancelAllOrders } from "../api/orders";
import { mexcEnv, BOT_DRY_RUN } from "../env";
import type { StrategySignal } from "../types";
import { rootLog } from "../logger";
import { computeOrderVolume } from "../risk/position-size";

export async function executeSignal(
  signal: StrategySignal,
  lastPrice: number,
  equityUsdt: number
): Promise<void> {
  if (signal.action === "hold") return;

  const vol = computeOrderVolume(equityUsdt, lastPrice, 0.0001);
  const base = {
    symbol: mexcEnv.symbol,
    openType: mexcEnv.openType,
    leverage: mexcEnv.leverage,
    price: lastPrice,
    vol,
  };

  if (signal.action === "close") {
    if (BOT_DRY_RUN) {
      rootLog.info("[dry-run] would cancel all orders", mexcEnv.symbol);
      return;
    }
    await cancelAllOrders(mexcEnv.symbol);
    rootLog.info("Cancelled open orders for", mexcEnv.symbol);
    return;
  }

  const side = signal.action === "open_long" ? 1 : 3;
  const type = 5;
  const payload = { ...base, side: side as 1 | 2 | 3, type: type as 5 };

  if (BOT_DRY_RUN) {
    rootLog.info("[dry-run] order", payload, signal.reason);
    return;
  }

  const ack = await submitOrder(payload);
  rootLog.info("Submitted order", ack.orderId, signal.reason);
}
EOF
commit "feat: add signal executor with dry-run and market order mapping"

# 29
cat > src/bot/runner.ts <<'EOF'
import { fetchKlines, fetchTicker } from "../api/market";
import { fetchOpenPositions } from "../api/positions";
import { fetchAccountAssets } from "../api/account";
import { setLeverage } from "../api/leverage";
import { BOT_POLL_INTERVAL_MS, BOT_STRATEGY, mexcEnv } from "../env";
import { rootLog } from "../logger";
import { sleep } from "../backoff";
import { isShuttingDown } from "../signals";
import { maCrossStrategy } from "../strategies/ma-cross";
import { gridStrategy } from "../strategies/grid";
import type { Strategy } from "../strategies/types";
import { validateSignal } from "../risk/manager";
import { executeSignal } from "./executor";
import { pickUsdtEquity } from "../risk/position-size";
import { withBackoff } from "../backoff";

function pickStrategy(): Strategy {
  return BOT_STRATEGY === "grid" ? gridStrategy : maCrossStrategy;
}

export async function runBotLoop(): Promise<void> {
  const strategy = pickStrategy();
  rootLog.info(`Strategy=${strategy.name} symbol=${mexcEnv.symbol} leverage=${mexcEnv.leverage}`);

  await withBackoff(() =>
    setLeverage(mexcEnv.symbol, mexcEnv.leverage, mexcEnv.openType)
  );

  while (!isShuttingDown()) {
    try {
      const [ticker, klines, positions, assets] = await Promise.all([
        fetchTicker(mexcEnv.symbol),
        fetchKlines(mexcEnv.symbol, "Min15", 120),
        fetchOpenPositions(mexcEnv.symbol),
        fetchAccountAssets(),
      ]);

      const equity = pickUsdtEquity(assets);
      const signal = strategy.evaluate({
        symbol: mexcEnv.symbol,
        klines,
        positions,
        lastPrice: ticker.lastPrice,
      });

      const risk = validateSignal(signal, positions, equity);
      if (risk.allowed) {
        await executeSignal(signal, ticker.lastPrice, equity);
      } else {
        rootLog.debug("Signal skipped:", risk.reason);
      }
    } catch (e) {
      rootLog.error("Tick failed:", e instanceof Error ? e.message : e);
    }

    if (isShuttingDown()) break;
    await sleep(BOT_POLL_INTERVAL_MS);
  }
}
EOF
commit "feat: add StrategyRunner orchestration loop with leverage priming"

# 30
cat > src/bot-run.ts <<'EOF'
import { assertMexcCredentials } from "./credentials";
import { logVersion, rootLog } from "./logger";
import { installShutdownHandlers } from "./signals";
import { runBotLoop } from "./bot/runner";

async function main(): Promise<void> {
  logVersion();
  assertMexcCredentials();
  installShutdownHandlers(() => rootLog.info("Shutdown requested; exiting after tick."));
  await runBotLoop();
}

void main().catch((e) => {
  console.error(e);
  process.exit(1);
});
EOF
commit "feat: add bot-run CLI driver with credential checks"

# 31 - add dependencies to package.json
node -e "
const fs=require('fs');
const p=JSON.parse(fs.readFileSync('package.json','utf8'));
p.dependencies={dotenv:'^17.2.3',undici:'^7.16.0'};
p.devDependencies={'@types/node':'^24.10.1',tsx:'^4.19.3',typescript:'^5.9.3'};
fs.writeFileSync('package.json', JSON.stringify(p,null,2)+'\n');
"
commit "chore: declare runtime and TypeScript dev dependencies"

# 32
cat > .env.sample <<'EOF'
# MEXC contract API (https://contract.mexc.com)
MEXC_BASE_URL=https://contract.mexc.com
MEXC_API_KEY=
MEXC_API_SECRET=
# Web session alternative:
# MEXC_KEY=
# MEXC_COOKIE=

MEXC_SYMBOL=BTC_USDT
MEXC_LEVERAGE=5
MEXC_OPEN_TYPE=1

BOT_STRATEGY=ma-cross
BOT_POLL_INTERVAL_MS=5000
BOT_DRY_RUN=true

RISK_MAX_POSITION_USDT=500
RISK_RISK_PERCENT=2
EOF
commit "docs: dotenv template for API keys strategy and risk flags"

# 33 - npm install for lockfile
if command -v npm >/dev/null; then
  npm install --package-lock-only 2>/dev/null || npm install 2>/dev/null || true
fi
if [[ -f package-lock.json ]]; then
  commit "chore: add npm dependency lockfile"
fi

# 34
cat > README.md <<'EOF'
# MEXC futures trading bot

TypeScript Node CLI for rule-based automation on MEXC USDT-margined perpetual contracts (`contract.mexc.com`). Ships with moving-average crossover and grid strategies, dry-run mode, and notional risk caps.

## Requirements

- Node.js 20+
- MEXC futures account with either **Open API** credentials (`MEXC_API_KEY` + `MEXC_API_SECRET`) or a **web session** key/cookie pair
- Sufficient USDT margin for the configured symbol and leverage

## Setup

```bash
cp .env.sample .env
npm install
```

## Commands

| Command | Description |
|---------|-------------|
| `npm run bot` | Long-running strategy loop (`BOT_DRY_RUN=true` recommended first). |
| `npm run build` | Emit `dist/`. |
| `npm run typecheck` | `tsc --noEmit`. |

## Strategies

- `ma-cross` (default): 9/21 SMA crossover filtered by RSI; closes on opposite cross.
- `grid`: Places conceptual buy bands below spot and takes profit toward upper grid levels.

Set `BOT_STRATEGY=grid` or `ma-cross` in `.env`.

## Safety

Always start with `BOT_DRY_RUN=true`. Perpetual futures carry liquidation risk—`RISK_MAX_POSITION_USDT` and `RISK_RISK_PERCENT` cap sizing but do not guarantee profitability.

See [`docs/architecture.md`](docs/architecture.md) for request flow notes.

## License

MIT — see [`LICENSE`](LICENSE).
EOF
commit "docs: README with setup commands strategies and safety notes"

# 35
mkdir -p docs
cat > docs/architecture.md <<'EOF'
# Architecture

```mermaid
flowchart TB
  CLI[bot-run.ts] --> Runner[bot/runner.ts]
  Runner --> Market[api/market.ts]
  Runner --> Pos[api/positions.ts]
  Runner --> Strat[strategies/*]
  Runner --> Risk[risk/manager.ts]
  Runner --> Exec[bot/executor.ts]
  Exec --> Orders[api/orders.ts]
  Orders --> HTTP[http/mexc-http.ts]
  HTTP --> MEXC[(contract.mexc.com)]
```

## Auth modes

1. **Open API** — `MEXC_API_KEY` + `MEXC_API_SECRET` with HMAC-SHA256 headers (`ApiKey`, `Request-Time`, `Signature`).
2. **Web session** — `MEXC_KEY` or `MEXC_API_KEY` as `Authorization`, optional `MEXC_COOKIE` and `MEXC_FINGERPRINT`.

## Tick lifecycle

Each poll interval loads ticker, 15m klines, open positions, and USDT equity, evaluates the active strategy, runs risk checks, then submits or simulates orders.
EOF
commit "docs: futures API flow and module architecture note"

# 36
cat > docs/strategies.md <<'EOF'
# Strategies

## MA Cross (`ma-cross`)

Uses 9- and 21-period simple moving averages on 15-minute closes. Entries require RSI confirmation (long when RSI < 65, short when RSI > 35). Exits flatten when the fast MA crosses back through the slow MA.

## Grid (`grid`)

Builds five spaced price bands around the last trade. Opens a long when price dips to the nearest lower band; closes when price reaches the nearest upper band. Best suited to ranging markets—trending markets may stack risk quickly.
EOF
commit "docs: strategy parameter reference for ma-cross and grid"

# 37
cat > CHANGELOG.md <<'EOF'
# Changelog

## 1.0.0

- Initial TypeScript CLI with MA-cross and grid strategies.
- MEXC contract REST client (Open API + web session auth).
- Dry-run mode and notional risk caps.
EOF
commit "docs: add project changelog scaffold"

# 38
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 mexc-future-trading-bot contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
commit "docs: include MIT license"

# 39
cat > SECURITY.md <<'EOF'
# Security

- Never commit `.env`, API secrets, or browser session cookies.
- Rotate `MEXC_API_KEY` / web session tokens if they leak.
- Run with `BOT_DRY_RUN=true` on staging accounts before live trading.
- Restrict server filesystem permissions on machines holding credentials.
EOF
commit "docs: security checklist for privileged API credentials"

# 40
echo "20" > .nvmrc
commit "chore: record Node 20 toolchain hint in .nvmrc"

# 41
cat > CONTRIBUTING.md <<'EOF'
# Contributing

1. Fork and branch from `main`.
2. `npm install` and `npm run typecheck`.
3. Keep commits focused; prefix with `feat:`, `fix:`, `docs:`, or `chore:`.
4. Open a PR describing strategy or risk changes and how you tested with `BOT_DRY_RUN`.
EOF
commit "docs: contributor workflow notes"

echo "Done. Commits: $(git rev-list --count HEAD)"
