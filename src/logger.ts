import { VERSION, SERVICE_NAME } from "./constants";

export interface Logger {
  info(...args: unknown[]): void;
  warn(...args: unknown[]): void;
  error(...args: unknown[]): void;
  debug(...args: unknown[]): void;
}

export const rootLog: Logger = {
  info: (...a) => console.log("[info]", ...a),
  warn: (...a) => console.warn("[warn]", ...a),
  error: (...a) => console.error("[error]", ...a),
  debug: (...a) => {
    if (process.env.LOG_DEBUG === "true") console.debug("[debug]", ...a);
  },
};

export function logVersion(): void {
  rootLog.info(`${SERVICE_NAME} v${VERSION}`);
}
