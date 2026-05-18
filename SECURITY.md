# Security

- Never commit `.env`, API secrets, or browser session cookies.
- Rotate `MEXC_API_KEY` / web session tokens if they leak.
- Run with `BOT_DRY_RUN=true` on staging accounts before live trading.
- Restrict server filesystem permissions on machines holding credentials.
