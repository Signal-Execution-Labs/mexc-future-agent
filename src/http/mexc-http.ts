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
