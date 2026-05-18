import { assertMexcCredentials } from "./credentials";
import { logVersion, rootLog } from "./logger";
import { installShutdownHandlers } from "./signals";
import { runBotLoop } from "./bot/runner";

async function main(): Promise<void> {
  logVersion();
  assertMexcCredentials();
  installShutdownHandlers(() => rootLog.info("Shutdown requested; exiting after tick."));
  await runBotLoop();
}

void main().catch((e) => {
  console.error(e);
  process.exit(1);
});
