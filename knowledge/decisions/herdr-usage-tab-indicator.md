---
type: Decision
title: Herdr Tab-Bar Claude Usage Indicator via State File
description: The Claude weekly-usage indicator renders through a ui.tab_bar_right command entry polling a /tmp state file that a per-pane watcher maintains from pushed tab.focused socket events — because herdr's right tab-bar edge is config-only and workspace metadata tokens render solely in the sidebar.
tags: [claude, herdr, statusline]
timestamp: '2026-08-30T13:45:00-07:00'
---

**Status:** active (experiment). **Where:**
[`home/claude-me/.claude-me/herdr-usage-watcher.ts`](../../home/claude-me/.claude-me/herdr-usage-watcher.ts),
[`home/claude-me/.claude-me/statusline.sh`](../../home/claude-me/.claude-me/statusline.sh),
[`home/herdr/.config/herdr/config.toml`](../../home/herdr/.config/herdr/config.toml)
([herdr](../modules/herdr.md)).

## Context

The Claude Code statusline should surface weekly rate-limit consumption
(all-models + Fable-scoped) in [herdr](../modules/herdr.md)'s tab bar,
right-aligned, only while the tab hosting the personal-profile claude is
focused. Three constraints shaped the design: herdr has no push API for the
tab bar's right edge; the OAuth usage endpoint that carries the per-model
number rate-limits aggressively; and the statusline script runs on every
refresh, so anything it spawns must be idempotent.

## Decision

- **Render channel:** a `ui.tab_bar_right` entry of type `command` that
  `cat`s `/tmp/herdr-claude-usage.txt` at `interval_seconds = 1` — the
  render-latency floor. Two rejected routes: `herdr tab rename` (clobbers the
  user's label and needs restore bookkeeping) and `workspace
  report-metadata` tokens (render only in the sidebar's space rows, never
  the tab bar — the `TabBarRightEntryConfig` enum was recovered via
  `strings` on the binary since neither the default config nor the API
  schema documents it).
- **Focus tracking:** the watcher subscribes to pushed `tab.focused` events
  on the herdr API socket (`$HERDR_SOCKET_PATH`, newline-delimited JSON, no
  handshake) instead of polling `herdr tab get` — the state file flips in
  ~35 ms; end-to-end latency is dominated by the 1 s render poll.
- **Data sources split by cost:** the all-models weekly % is free — the
  statusline JSON's `rate_limits.seven_day` — so `statusline.sh` publishes
  it to `/tmp/herdr-claude-weekly.json` at zero API calls. Only the
  Fable-scoped % needs `api.anthropic.com/api/oauth/usage` (`limits[]`
  kind `weekly_scoped`), which 429s hard under bursts (~25 calls in 10 min
  locked the token out >5 min despite `retry-after: 1`): fetched through a
  cache shared by all watcher instances, 30-min TTL, 15-min failure
  backoff. The OAuth token comes from the profile's Keychain entry
  (`"Claude Code-credentials-" + sha256(configDir)[0:8]`; see
  [claude profile isolation](claude-profile-isolation.md)).
- **Rendering:** [dotbar](../packages/dotbar.md) `--dense` bars,
  ANSI-stripped — the tab bar is plain text, and the braille glyphs carry
  the fill level without color.
- **Lifecycle:** `statusline.sh` spawns the watcher on every refresh; a
  per-pane pidfile claimed with an exclusive-create (`wx`) keeps it a
  singleton under that spawn rate. It exits with its claude process, and a
  5 s housekeeping tick re-asserts the state file if another instance's
  exit cleanup removed it.

## Consequences

- Indicator appears/disappears within ~1 s of a tab switch; steady-state
  API cost is ~2 requests/hour regardless of pane count.
- Deployed on both OSes per the
  [split stow packages](claude-skills-split-stow-packages.md) convention:
  the real files live in `claude-me` (on the macs `~/.claude` is the
  account-selector's unowned symlink that stow refuses to traverse), with
  repo-internal symlinks mirroring watcher + statusline into the `claude`
  package for nebula. There the `default` profile (no account selector, so
  `CLAUDE_CONFIG_DIR` unset) counts as personal in the spawn gate, and the
  Fable fetch degrades to a wk-only indicator since macOS `security` is
  absent. Nebula still needs `statusLine` pointed at the script in its
  untracked `~/.claude/settings.json`.
- The 1 s `cat` poll runs on the herdr server whether or not claude is up;
  the `tab_bar_right` schema is undocumented upstream and may shift.
- Superseded next by the [token-bar patch](herdr-token-bar-patch.md): the
  watcher already dual-publishes `usage`/`usage_fable` workspace tokens, and
  the state-file mechanism retires once the patched binary is live.

## Citations

- Commits `1973a19` (watcher + herdr config), `dbe7e12` (statusline adoption)
- [Claude Code statusline JSON reference](https://code.claude.com/docs/en/statusline)
- [herdr repository](https://github.com/herdrdev/herdr)
