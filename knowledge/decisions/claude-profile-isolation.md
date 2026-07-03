---
type: Decision
title: Claude Profile Isolation Strategy
description: The claude wrapper prefers each profile's own interactive login and uses the Keychain token only as a fallback; the desktop app is pinned via a launchd Aqua-domain setenv plus a shell scrub.
resource: modules/darwin/claude-account-selector/README.md
tags: [claude, credentials, macos]
timestamp: '2026-07-02T00:00:00-07:00'
---

**Status:** active. **Where:**
[claude-account-selector](../modules/claude-account-selector.md).

## Context

Two Claude Code accounts (personal Max + corporate Enterprise) must coexist on
one machine, simultaneously. Older Claude Code stored the OAuth login in a
single shared macOS Keychain item, so profiles fought over one login even with
separate `CLAUDE_CONFIG_DIR`s — a per-profile Keychain token was the only way
to get true simultaneous use. Claude Code ≥ 2.1.165 (verified) isolates the
login per `CLAUDE_CONFIG_DIR`.

## Decision

- The wrapper **prefers each profile's interactive login** and injects the
  Keychain token (`claude-token-<profile>`) only when a probe
  (`claude auth status --json`, token blanked) reports the profile is *not*
  signed in — covering fresh dirs, expired sessions, and Enterprise accounts
  where interactive login isn't available.
- Profile selection is longest-prefix match of `$PWD` against declarative Nix
  rules merged with runtime `claude pin` entries.
- The GUI desktop app never sees `$PWD`, so `desktopProfile` pins it via a
  per-user LaunchAgent running `launchctl setenv CLAUDE_CONFIG_DIR …` in the
  Aqua domain — and because that leaks into GUI-launched terminals (which
  would disable per-directory switching), the module prepends a zsh scrub
  that drops the exact inherited value in interactive shells.
- A matching `ccglass` function applies the same resolution for the traffic
  inspector, which spawns the real `claude` binary directly and would
  otherwise bypass the wrapper.

## Consequences

- Both accounts stay signed in at once with no token at all in the common case.
- Stateful subcommands (`claude mcp add`, …) are cwd-scoped to the resolved
  profile — intentional, occasionally surprising.
- The desktop app gets one fixed profile; ~0.2 s auth probe per launch.

## Citations

- [Module README](../../modules/darwin/claude-account-selector/README.md)
