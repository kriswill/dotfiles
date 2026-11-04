---
type: Decision
title: Track AI Account Usage with a Bun Daemon and a Draw-Only herdr-app Mod
description: 'Usage tracking for Claude Ultra, the Anthropic API and ChatGPT runs in a Bun daemon that owns credentials and rate-limit pacing and writes a JSON snapshot; the herdr-app mod only watches and draws it, because mods are sandboxed JS that can''t hold a 1Password-sourced key across polls.'
tags: [herdr, ai, secrets, 1password]
status: stable
generated: { by: codex/gpt-6, at: 2026-11-01T17:00:00-08:00 }
sources:
  - id: usage-cost-api
    resource: https://platform.claude.com/docs/en/api/usage-cost-api
    title: Claude Platform — Usage and Cost API
  - id: codexbar
    resource: https://github.com/steipete/CodexBar
    title: steipete/CodexBar
  - id: op-read
    resource: https://developer.1password.com/docs/cli/reference/commands/read/
    title: 1Password CLI `op read`
---

**Where:** [ai-usage package](../packages/ai-usage.md),
[ai-usage module](../modules/ai-usage.md), [herdr](../modules/herdr.md).

## Context

The goal was one labelled panel (logo, title, a bar, $ where it applies) in
herdr-app for three accounts: Claude Ultra (Claude Code), the Anthropic API key
Hermes uses ([nebula-hermes-agent](../modules/nebula-hermes-agent.md)), and
ChatGPT Plus. It had to work on macOS and Linux.

Herdr mods are JavaScript on gpui-kit: no Node or Bun APIs, no `setTimeout`,
and assets only from inside `~/.config/herdr-app`. They do have `exec` and
`fetch`, so a mod could poll the providers itself. Each source pushed back:

- Claude's `api/oauth/usage` is quota-limited per account and already shared
  by `herdr-usage-watcher.ts` and `claude-usage-work.ts`. Polling from every
  mod copy, on every host, would exhaust it.
- Anthropic API cost needs an Admin key.[^usage-cost-api] Kept in 1Password
  (see [python-keyring-op-backend](python-keyring-op-backend.md) for how
  flaky a cold `op` handshake is), it would cost an `op read` per poll, and
  each read can raise an approval prompt.[^op-read]
- Codex's and Claude's OAuth refresh tokens rotate, so nothing but their own
  CLIs may refresh them.

## Decision

Split collection from drawing:

- **`ai-usage daemon`** (Bun/TypeScript, [package](../packages/ai-usage.md)),
  run as a user service on nebula and a launchd agent on the macs. It reads
  the Admin key once into memory, polls each account on its own schedule
  (Claude every 10 min, `retry-after` honoured and persisted), and only reads
  OAuth tokens, as CodexBar does.[^codexbar] It writes
  `~/.cache/ai-usage/usage.json`, which holds no secrets. `SIGUSR1`
  (`ai-usage refresh`) refetches and retries a failed `op`.
- **The `ai-usage` mod** watches that folder (`watchFolder`), so it redraws
  on each write without polling. ↻ runs `ai-usage refresh`, and a click
  opens the account's usage page. In the sidebar rail it shrinks to logos
  over mini-bars.
- **Config** is a stow-managed JSON file (`hosts` filter, `configDir`
  candidates for the macs' `~/.claude-me`), editable without a rebuild.

Token renewal is delegated to each provider's official client rather than
leaving an unattended collector stuck on an expired login: Codex's
app-server, and for Claude (since 2026-11-04) a prompt-less `claude -p`
session's `get_usage` control request, which renews the login under Claude
Code's lock and returns the usage body in the same step. The collector
still never performs the OAuth exchange itself. Optional local dollar
estimates are explicitly separate from billed spending: they use local
session counters and published standard API rates, with coverage and
exclusions shown on the card. Details and upstream references are in the
[package doc](../packages/ai-usage.md#codex-collection-and-local-estimates).

Rejected: a mod-only tracker (the reasons above); sops for the Admin key
(it works unattended, but 1Password is where the user keeps keys, and the
daemon makes a single read cheap enough).

## Consequences

- The terminal view works without Herdr (over ssh, say). The macs' Herdr
  shows the same panel, and it fills once a host enables `services.ai-usage`.
- After a restart, the daemon asks 1Password once. If that fails, the API
  card reads "refresh to retry" and the other cards keep working.
- The API card is off for now: nebula's Console account is an individual
  org, which gets no Admin API reports, and the only other source of billed
  cost is the Console's login session. Hermes' own estimate (the `hermes`
  provider) matched a settled day, but was left out with it. Details in the
  [package doc](../packages/ai-usage.md).
- Console orgs can't read their spend limit through the API, so the API
  bar's maximum is a hand-set `budget`.
- **Herdr won't load a symlinked image.** Stow links every mod file into the
  repo, and `image()`/`svg()` refuse a path that resolves outside
  `~/.config/herdr-app`. So the mod copies its logos into a hidden `.logos/`
  as real files at init (hidden files don't trigger a reload). Relatedly,
  editing a stowed mod file in the repo doesn't hot-reload it; `touch -h`
  the link in `~/.config/herdr-app/mods/<mod>/`.
- ChatGPT's chat limits have no API; the card tracks Codex's limits once
  `codex login` has run.

[^usage-cost-api]: Claude Platform — Usage and Cost API
[^op-read]: 1Password CLI `op read`
[^codexbar]: steipete/CodexBar
