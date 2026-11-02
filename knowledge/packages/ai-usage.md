---
type: Overlay
title: Ai Usage
description: 'ai-usage — a Bun collector for AI account usage (Claude Max plan limits and extra usage, Anthropic API month-to-date cost, ChatGPT Codex limits): a rate-limit-paced daemon plus a terminal view, drawn in herdr-app by the ai-usage mod.'
resource: overlays/ai-usage.nix
tags: [overlay, package, herdr]
generated: { by: claude-code/opus-5.5, at: 2026-11-01T16:05:00-08:00 }
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
| `codex` | `$CODEX_HOME/auth.json` (or the `Codex Auth` keychain item) | `chatgpt.com/backend-api/wham/usage`[^openai-codex] | 5h and weekly windows, extras, credits |

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
- **OAuth tokens are read, never refreshed.** Claude's and Codex's refresh
  tokens rotate; redeeming one would sign the CLI out. An expired token
  shows "open Claude Code / run codex" until the CLI renews it.
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
[^codexbar]: steipete/CodexBar
[^simple-icons]: Simple Icons (the mod's logos, CC0)
