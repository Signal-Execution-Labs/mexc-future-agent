import { brotliDecompressSync, gunzipSync, inflateRawSync, inflateSync } from "node:zlib";

export function decodeBody(buf: Buffer, encoding: string | undefined): string {
  if (!buf.length) return "";
  const enc = (encoding || "").toLowerCase().trim();
  try {
    if (enc === "gzip" || enc === "x-gzip") return gunzipSync(buf).toString("utf8");
    if (enc === "br") return brotliDecompressSync(buf).toString("utf8");
    if (enc === "deflate") {
      try {
        return inflateSync(buf).toString("utf8");
      } catch {
        return inflateRawSync(buf).toString("utf8");
      }
    }
  } catch {
    /* fall through */
  }
  return buf.toString("utf8");
}

export function firstHeader(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}
