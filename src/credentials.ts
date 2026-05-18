import { mexcEnv } from "./env";

export function assertMexcCredentials(): void {
  const hasOpenApi =
    mexcEnv.apiKey.trim() !== "" && mexcEnv.apiSecret.trim() !== "";
  const hasWebSession =
    mexcEnv.apiKey.trim() !== "" || mexcEnv.cookie.trim() !== "";
  if (!hasOpenApi && !hasWebSession) {
    throw new Error(
      "Set MEXC_API_KEY + MEXC_API_SECRET (Open API) or MEXC_KEY/MEXC_COOKIE (web session)."
    );
  }
}

export function usesOpenApiAuth(): boolean {
  return mexcEnv.apiKey.trim() !== "" && mexcEnv.apiSecret.trim() !== "";
}
