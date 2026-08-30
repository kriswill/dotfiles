---
type: Overlay
title: Git Yazi
description: 'git.yazi — bump nixpkgs'' pinned snapshot (0-unstable-2026-08-03, written for the pre-26.8 fetcher API) to upstream HEAD.'
resource: overlays/git-yazi.nix
tags: [overlay]
timestamp: '2026-08-19T12:00:51-07:00'
---

git.yazi — bump nixpkgs' pinned snapshot (0-unstable-2026-08-03, written for the pre-26.8 fetcher API) to upstream HEAD. Under yazi 26.8.15 the old plugin's fetch() contract leaves fetcher tasks permanently pending, so yazi accumulates "git" background tasks and prompts to abort them on quit. Upstream rewrote the plugin for the new fetcher API on 2026-08-18 ("simplify with new fetcher API", yazi-rs/plugins@6f26ae0); nixpkgs hasn't picked it up yet. Drop this once nixpkgs' yaziPlugins.git is at or past that commit.

## Source

- Overlay: [`overlays/git-yazi.nix`](../../overlays/git-yazi.nix)
