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
