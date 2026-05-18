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
