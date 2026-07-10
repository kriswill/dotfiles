---
type: Decision
title: Shim The Chrome.app Path Instead Of Rewiring MCP Config
description: 'Point Chrome-only tooling at Helium by planting an exec-wrapper at the path Puppeteer probes, rather than overriding the chrome-devtools-mcp plugin''s args or replacing its MCP server.'
tags: [darwin, browser, mcp]
timestamp: '2026-07-10T17:05:00+00:00'
---

**Status:** active. **Where:** [helium-chrome-shim](../modules/helium-chrome-shim.md).

## Context

Removing the chromium cask from [Homebrew](../modules/homebrew.md)
(2026-07-10, Helium replaced it as the browser) broke chrome-devtools-mcp on
the Macs: Puppeteer resolves channel `stable` by probing the literal path
`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`
(existence-only `accessSync`), honors **no env var**, and the Claude Code
plugin invokes `npx chrome-devtools-mcp` with no browser flag. Claude Code
has no supported way to override a plugin-provided MCP server's args in
place. The candidate fixes:

1. **Patch the plugin's bundled `plugin.json`** to add
   `--executablePath` — wiped on every plugin version update.
2. **Deny the plugin's server + define a user-scoped replacement** — durable,
   but the tools move namespace (`mcp__plugin_…` → `mcp__chrome-devtools__…`),
   breaking existing permission allowlists and the plugin's bundled skills.
3. **Plant a shim at the probed path** (Kris' idea) — no Claude config
   touched at all.

## Decision

Option 3: `modules/darwin/helium-chrome-shim.nix` installs a 2-line `#!/bin/sh`
wrapper at the probed path that `exec`s
`/Applications/Helium.app/Contents/MacOS/Helium "$@"`. `exec` preserves the
PID, so Puppeteer's process handling is untouched: args and the CDP pipe
(fds 3/4) pass through; `browser.close()` reaps Helium on server stop;
`--browserUrl` attach still merely disconnects. Verified empirically over the
full matrix (headful/headless × isolated/persistent × SIGTERM/stdin-EOF ×
attach). Guards: skip + self-clean when Helium.app is absent; never touch a
real Chrome (Mach-O, not `#!`).

## Consequences

- chrome-devtools-mcp, and anything else resolving Chrome `stable` (e.g.
  Playwright `channel: "chrome"`), transparently uses Helium — surviving
  plugin updates, permission allowlists untouched.
- A fake `Google Chrome.app` exists in /Applications: not Finder-launchable
  (no `Info.plist`), invisible to the tooling's version checks (there are
  none), but a human browsing /Applications may be briefly confused — the
  wrapper's comment points at the module.
- If real Google Chrome is ever wanted on a Mac, the guard yields to it, and
  Chrome-channel tooling silently switches back from Helium — remove the
  module (or Helium) consciously at that point.
- chrome-devtools-mcp 1.5.0 offers no close-browser tool; launched Helium
  windows close when the MCP server stops (session end / `/mcp` reconnect).
  Upstream behaviour, unchanged by the shim.

## Citations

- Manual entry: [`docs/helium.md`](../../docs/helium.md) (2026-07-10 learned behaviour)
- chrome-devtools-mcp — <https://github.com/ChromeDevTools/chrome-devtools-mcp>
