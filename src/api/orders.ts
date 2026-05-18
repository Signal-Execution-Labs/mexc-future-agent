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
