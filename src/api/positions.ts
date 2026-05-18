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
