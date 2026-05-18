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
