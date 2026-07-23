---
type: Decision
title: Vendor faster-piper.yazi with Detached Cache Generation
description: The faster-piper yazi plugin is vendored into the stow tree as a patched fork whose cache generation runs in a detached daemon with atomic install, because upstream's in-place cache writes let interrupted previews cache blank/corrupt output.
resource: home/yazi/.config/yazi/plugins/faster-piper.yazi/main.lua
tags: [yazi, fork, caching]
timestamp: '2026-07-22T00:00:00-07:00'
---

**Status:** active. **Where:** [yazi](../modules/yazi.md).

## Context

Rapidly moving through the file list cancels yazi's in-flight peek task, and
yazi kills the renderer process the task spawned. Upstream faster-piper
(`alberti42/faster-piper.yazi`, no fix as of its latest commit `8b794bf`,
2026-02-02) rendered with a shell that wrote glow's output **directly to the
final cache path** before assembling the header, and held its mkdir lock from
the Lua side. A cancelled render therefore left a corrupt header-less file at
the final cache path and leaked the lock until its 60s TTL — markdown files
hit mid-scroll previewed blank/broken afterwards.

## Decision

- Vendor an MIT-licensed fork into the stow tree
  (`home/yazi/.config/yazi/plugins/faster-piper.yazi/`, LICENSE alongside),
  user-owned and live-editable like `font-dark`; drop the
  `faster-piper-yazi` flake input and its activation symlink.
- Rewrite generation as a fire-and-forget daemon: the spawned `sh`
  backgrounds a subshell and exits within milliseconds, so task cancellation
  can no longer kill the render. The daemon acquires the lock itself
  (atomic `mkdir`, stale-broken after ~60s via `find -mmin +1`), renders
  into unique `$$`-suffixed tmp files, installs the cache with an atomic
  `mv`, and releases the lock in an `EXIT` trap.
- On generator failure the daemon moves stderr to a `<cache>.failed` marker;
  Lua reports it instead of burning the 5s poll timeout on every peek, and
  ignores the marker once the source file's mtime advances.
- Lua never writes the final cache path and never owns the lock — it only
  spawns the daemon and polls `wait_for_ready_cache`.

## Consequences

- An interrupted preview either completes anyway (detached) or leaves the
  previous cache state untouched — a blank/corrupt preview can no longer be
  cached, and the lock cannot leak from Lua-side cancellation.
- Concurrent renders (two yazi instances have per-instance lock names) are
  now safe: atomic install, last writer wins; upstream's in-place writes
  could interleave.
- Upstream bumps become manual diffs against the vendored copy (provenance
  header in `main.lua`); watch upstream for a proper fix to re-converge.
- A SIGKILLed daemon is the one path that still leaves tmp litter and a lock
  dir; the ~60s stale-break covers the lock, litter sits in yazi's cache dir.

## Citations

- [alberti42/faster-piper.yazi](https://github.com/alberti42/faster-piper.yazi) — upstream, vendored at `8b794bf`
- Verified by scenario tests: SIGKILL mid-render leaves the final cache
  untouched; detached render survives spawner death; stale-lock break;
  `.failed` marker lifecycle (2026-07-22)
