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
