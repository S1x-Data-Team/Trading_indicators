1. MT5 Indicators — School Run Sessions (AM and PM)

This folder contains MetaTrader 5 (MQL5) indicators that draw two horizontal lines at the high and low of a specific 15-minute candle each trading day. It includes separate indicators for the morning and afternoon sessions.

SchoolRun_AM.mq5 draws lines based on a morning M15 candle (for example, the 10:15–10:30 server-time bar).

SchoolRun_PM.mq5 draws lines based on an afternoon M15 candle (for example, the 16:15–16:30 server-time bar).

Both indicators:

Anchor timing to the broker’s D1 open (server midnight) for reliable alignment

Let you choose colors, line styles, and width from Inputs

Can extend lines to end-of-day or ray infinitely to the right

Clean up their objects when the indicator is removed

Support multiple instances via an InstanceTag suffix



Notes on time

Server time may differ from your local time. Always set TargetHourServer/TargetMinuteServer according to the broker’s server clock.

Indicators anchor to iTime(_Symbol, PERIOD_D1, shift) to detect each server day reliably.



2. MT5 Discord Trade Notifier

Lightweight MetaTrader 5 Expert Advisor that relays your trade executions to a Discord channel via a webhook. It listens for opens, closes, and partial closes (and optionally SL/TP changes), then posts a clean text message. Works with manual trades or other EAs.

Features

Sends trade events to Discord via webhook (HTTP POST)

Optional startup “bot online” ping

Toggle fields: SL/TP, magic number, account line

Duplicate guard so the same deal isn’t posted from multiple charts

Simple, single-file EA (no DLLs)

Quick setup

MT5 → Tools → Options → Expert Advisors → Allow WebRequest; add:

https://discord.com

https://discordapp.com

your full webhook URL

Compile DiscordNotifier.mq5 in MQL5/Experts/.

Attach to any chart, enable Algo Trading, paste your webhook in Inputs.

Notes

Uses OnTradeTransaction, so it captures both manual and EA executions.

Account line can be disabled in Inputs (default recommended for privacy).
