let shuttingDown = false;

export function installShutdownHandlers(onShutdown: () => void): void {
  const handler = () => {
    if (shuttingDown) return;
    shuttingDown = true;
    onShutdown();
  };
  process.on("SIGINT", handler);
  process.on("SIGTERM", handler);
}

export function isShuttingDown(): boolean {
  return shuttingDown;
}
