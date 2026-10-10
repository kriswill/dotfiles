---
type: Darwin Module
title: Helium Chrome Shim
description: 'Plants an exec-wrapper at the canonical Google Chrome.app binary path on every rebuild, so Chrome-only tooling (chrome-devtools-mcp / Puppeteer channel ''stable'') launches Helium — no per-tool --executablePath wiring.'
resource: modules/darwin/helium-chrome-shim.nix
tags: [darwin-module]
generated: { by: okflight/0.4.0, at: 2026-07-10T16:43:25+00:00 }
sources:
  - id: manual-docs-helium-md
    resource: ../../docs/helium.md
    title: 'Manual: docs/helium.md'
  - id: chrome-devtools-mcp
    resource: https://github.com/ChromeDevTools/chrome-devtools-mcp
    title: chrome-devtools-mcp
  - id: puppeteer-browser-resolution-puppeteer-browsers
    resource: https://pptr.dev/browsers-api
    title: Puppeteer browser resolution (`@puppeteer/browsers`)
  - id: helium-browser
    resource: https://helium.computer/
    title: Helium browser
---

Puppeteer resolves channel `stable` on macOS by probing exactly
`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` with an
existence-only `accessSync` (no identity/version check) and offers **no
env-var override** — so after the Chromium cask was dropped from
[Homebrew](homebrew.md), chrome-devtools-mcp broke on the Macs. This module's
`postActivation` script (order 1700, root) installs a 2-line `#!/bin/sh`
wrapper at that path that `exec`s Helium's real binary: `exec` keeps the PID,
so Puppeteer's launch **and** close semantics are unchanged (`browser.close()`
reaps Helium; attach via `--browserUrl` disconnects without killing).
Verified 2026-07-10 across headful/headless × isolated/persistent-profile ×
SIGTERM/stdin-EOF. Why a filesystem shim and not MCP config: see the
[decision record](../decisions/helium-chrome-shim.md).

Guards make it safe as a universal module: no-op (and self-cleaning) when
`Helium.app` is absent, and it refuses to touch a real Google Chrome (Mach-O
magic, not `#!`). One host-selective option, `programs.helium-chrome-shim.purgeGoogleChrome`
(on for [k](../hosts/k.md)), flips that last guard: it boots out and deletes
Google's system updater (GoogleUpdater/Keystone daemons, install dirs, ticket
stores) and any real `Google Chrome.app` before re-planting the shim. Needed
because the updater's stale `com.google.Chrome` ticket treated the version-less
shim as "Chrome 0.0.0.0" and reinstalled a real Chrome over it (2026-08-27);
see the [decision record](../decisions/helium-chrome-shim.md). Not for hosts
running Google Drive for desktop (shares Keystone). Helium itself is installed manually on the Macs (not a cask,
unlike [nebula's nix-managed Helium](helium.md)). MCP-launched sessions use a
separate profile (`~/.cache/chrome-devtools-mcp/`), never the user's real one.

Mounted ungated on every darwin host
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/helium-chrome-shim.nix`](../../modules/darwin/helium-chrome-shim.nix)
