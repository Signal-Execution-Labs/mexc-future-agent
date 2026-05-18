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
