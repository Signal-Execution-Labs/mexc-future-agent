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
