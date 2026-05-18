import { mexcRequest } from "../http/mexc-http";
import type { AccountAsset } from "../types";

export async function fetchAccountAssets(): Promise<AccountAsset[]> {
  return mexcRequest<AccountAsset[]>("GET", "/api/v1/private/account/assets");
}
