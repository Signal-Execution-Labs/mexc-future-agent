# MEXC futures trading bot

TypeScript Node CLI for rule-based automation on MEXC USDT-margined perpetual contracts (`contract.mexc.com`). Ships with moving-average crossover and grid strategies, dry-run mode, and notional risk caps.

## Requirements

- Node.js 20+
- MEXC futures account with either **Open API** credentials (`MEXC_API_KEY` + `MEXC_API_SECRET`) or a **web session** key/cookie pair
- Sufficient USDT margin for the configured symbol and leverage

## Setup

```bash
cp .env.sample .env
npm install
```

## Commands

| Command | Description |
|---------|-------------|
| `npm run bot` | Long-running strategy loop (`BOT_DRY_RUN=true` recommended first). |
| `npm run build` | Emit `dist/`. |
| `npm run typecheck` | `tsc --noEmit`. |

## Strategies

- `ma-cross` (default): 9/21 SMA crossover filtered by RSI; closes on opposite cross.
- `grid`: Places conceptual buy bands below spot and takes profit toward upper grid levels.

Set `BOT_STRATEGY=grid` or `ma-cross` in `.env`.

## Safety

Always start with `BOT_DRY_RUN=true`. Perpetual futures carry liquidation risk—`RISK_MAX_POSITION_USDT` and `RISK_RISK_PERCENT` cap sizing but do not guarantee profitability.

See [`docs/architecture.md`](docs/architecture.md) for request flow notes.

## License

MIT — see [`LICENSE`](LICENSE).
