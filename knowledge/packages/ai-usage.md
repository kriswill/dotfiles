---
type: Overlay
title: Ai Usage
description: 'ai-usage — a Bun collector for AI account usage (Claude Ultra plan limits and extra usage, Anthropic API month-to-date cost, ChatGPT Codex limits): a rate-limit-paced daemon plus a terminal view, drawn in herdr-app by the ai-usage mod.'
resource: overlays/ai-usage.nix
tags: [overlay, package, herdr]
generated: { by: codex/gpt-6, at: 2026-11-01T17:00:00-08:00 }
sources:
  - id: usage-cost-api
    resource: https://platform.claude.com/docs/en/api/usage-cost-api
    title: Claude Platform — Usage and Cost API (Admin API)
  - id: codexbar
    resource: https://github.com/steipete/CodexBar
    title: steipete/CodexBar (reference for the Claude OAuth and Codex usage endpoints)
  - id: openai-codex
    resource: https://github.com/openai/codex
    title: openai/codex (`backend-client` wham/usage, `login` auth.json)
  - id: codex-app-server
    resource: https://learn.chatgpt.com/docs/app-server
    title: Codex app-server account protocol
  - id: openai-pricing
    resource: https://developers.openai.com/api/docs/pricing
    title: OpenAI API pricing
  - id: simple-icons
    resource: https://simpleicons.org/
    title: Simple Icons (the mod's logos, CC0)
---

One Bun script wrapped by `writeShellApplication`, the
[system-update-report](system-update-report.md) shape:
`ai-usage [show [--json] | refresh | once [--force] | daemon | path | config]`.
The [ai-usage module](../modules/ai-usage.md) runs the daemon; the design is
recorded in a [decision](../decisions/ai-usage-collector-daemon.md).

## Providers

| `provider` | Reads | Endpoint | Meters |
|---|---|---|---|
| `claude` | Claude Code's OAuth login (`.credentials.json`, or the macOS keychain item hashed from the config dir) | `api.anthropic.com/api/oauth/usage` | session (when present), weekly, per-model weekly (`limits[]`), cloud credits, extra usage $ |
| `anthropic-api` | an **Admin** key, `sk-ant-admin01-…`[^usage-cost-api] | `/v1/organizations/cost_report`, paged, summed | this month $ (toward `budget`), today $ |
| `hermes` | Hermes' `state.db` (`session_model_usage`, its own list-price estimate) | none | this month $, today $ |
| `codex` | `$CODEX_HOME/auth.json` (or the `Codex Auth` keychain item), optional local session logs | `chatgpt.com/backend-api/wham/usage`[^openai-codex] | 5h and weekly windows, extras, credits, local API-equivalent estimate |

## Codex collection and local estimates

The ChatGPT title is plan-neutral; the live plan appears in the subtitle.
The usage service's `prolite` tier is displayed as **Pro**. Subscription
price remains an explicit config value (currently $100/month, supplied by
the account owner), since the usage response does not return a price.

The Herdr widget shows only meters with percentage bars and collection
errors. Credits, local cost figures and informational disclaimers are hidden
in both full cards and rail tooltips. Local cost collection is disabled in
the shared config. Codex daily, weekly, code-review and additional model
windows render as bars when returned by the service; the current $100 Pro
response supplies only a weekly window (verified 2026-11-01).

Optional `localCost: true` adds **Today est.** and
**Month est.** from `sessions/` and `archived_sessions/` under `codexHome`.
These are local API-equivalent estimates at standard prices, **not billed
spending or a conversion of the subscription quota**. Prices are explicit
USD per million input/cached-input/output tokens, verified 2026-11-01;
unknown models are omitted with a visible notice.[^openai-pricing] Update
the table when adding models or when published prices change.

The parser follows model changes, subtracts cumulative counters, ignores
duplicate notifications, and deduplicates copied fork/archive history.
Periods use local calendar days/months and event timestamps; changed files
are cached in memory. Logs on other devices, tool charges and speed/context
surcharges are excluded. Logs in one Codex home may span multiple accounts;
the estimate describes that local history, not an account billing ledger.
No priced events means no dollar meters, rather than a misleading $0.

Expired logins are renewed by `codex app-server` using
`account/read` with `refreshToken: true`, with a 30-second timeout; the
collector never redeems the refresh token itself.[^codex-app-server]
The service finds Codex on PATH or in `~/.local/bin` / `~/.nix-profile/bin`.
Failed renewal shows a `codex login` recovery message. Credit balances of
zero are visible; absent credit fields are not guessed.

On 2026-11-01, host [k](../hosts/k.md) had a stale one-shot snapshot but no
installed collector or launchd agent, despite the module being enabled in
the checkout. A config change needs activation: `nrs` installs both the
command and service. A snapshot alone does not establish that polling is
running. Check `ai-usage show` and the launchd service
`gui/$(id -u)/org.nixos.ai-usage` (Linux: the user systemd service).

The fix was activated on k without a full system switch: the built package
is GC-rooted at `~/.local/state/ai-usage/package`, its generated-equivalent
launchd plist uses the normal `org.nixos.ai-usage` label, and a
`~/.local/bin/ai-usage` launcher prefers the system command once `nrs`
installs it. Herdr also tries this local path and now displays command
errors even when an old snapshot exists. The working panel was visually
verified with quota bars, credits, and both estimate rows.

Regression checks: `bun test pkgs/ai-usage/main.test.ts`.

## Gotchas

- **No Anthropic API card for now** (2026-11-01, by choice). nebula's Console
  account is an *individual* org, and individual orgs get no Admin API
  reports.[^usage-cost-api] Its unscoped personal key reaches
  `/v1/organizations/me` (200), but `cost_report`, `usage_report` and
  `api_keys` answer 403 "Missing permissions", `analytics/cost` answers
  404, and `/settings/admin-keys` is a 404 page. Both providers still work;
  re-adding the card is a config entry.
  - **The Console page itself** calls `platform.claude.com/v1/organizations/analytics/cost`
    authenticated by the login session cookie plus an `x-organization-uuid`
    header (no key), and reads the credit balance from
    `/api/organizations/<uuid>/prepaid/credits`. That cookie is the whole
    login, so it was left alone. The cost data refreshes in batches every few
    hours: at 23:32 UTC it held 67 of the day's 248 Hermes requests.
  - **The `hermes` estimate is accurate on a settled day:** Oct 29 came to
    $4.85 against the Console's ~$5. It counts only Hermes' calls, and only
    on nebula.

- **The Claude endpoint is quota-limited per account**, and the herdr TUI's
  `herdr-usage-watcher.ts` and `claude-usage-work.ts` share the bucket. The
  daemon polls every 10 min, honours `retry-after` exactly (persisted, so a
  restart can't skip it), and a forced refresh still waits a minute.
  CodexBar does the same.[^codexbar]
- **OAuth refresh belongs to the provider's client.** Claude waits for its
  CLI; Codex renewal is delegated to the official app-server. The collector
  does not implement a competing refresh-token exchange.
- **Cost needs an Admin API credential:** an Admin key (`sk-ant-admin01-`,
  created by an org admin under Settings → Admin keys), or a personal key
  that isn't scoped to a workspace, which carries its user's role. A plain
  `sk-ant-api` key can't read cost. Neither can a personal key that fails
  either condition: the first one tried got 403 "Missing permissions".
  Console orgs also have no API for their spend limit or credit balance
  (the spend-limits API is Enterprise-only), so the bar's maximum is
  `budget` in the config.
- **Cost buckets are UTC days**, and `amount` is a decimal string in cents.
- **ChatGPT chat limits have no API**; only Codex's are visible, and only
  after `codex login` with ChatGPT.
- The response names some buckets with codenames (`iguana_necktie` = cloud
  credits); unknown ones are ignored rather than guessed at.

## Source

- Package: [`pkgs/ai-usage/package.nix`](../../pkgs/ai-usage/package.nix), script [`pkgs/ai-usage/main.ts`](../../pkgs/ai-usage/main.ts)
- Overlay: [`overlays/ai-usage.nix`](../../overlays/ai-usage.nix) — exposes `pkgs.ai-usage`
- Config: [`home/ai-usage/.config/ai-usage/config.json`](../../home/ai-usage/.config/ai-usage/config.json)
- Mod: [`mods/ai-usage/main.js`](../../home/herdr-app/.config/herdr-app/mods/ai-usage/main.js), logos from Simple Icons[^simple-icons]

[^usage-cost-api]: Claude Platform — Usage and Cost API (Admin API)
[^openai-codex]: openai/codex (`backend-client` wham/usage, `login` auth.json)
[^codex-app-server]: Codex app-server account protocol
[^openai-pricing]: OpenAI API pricing
[^codexbar]: steipete/CodexBar
[^simple-icons]: Simple Icons (the mod's logos, CC0)
