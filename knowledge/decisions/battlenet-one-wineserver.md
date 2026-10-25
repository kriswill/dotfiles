---
type: Decision
title: One Wineserver per Battle.net Prefix
description: 'The battlenet launcher shares the host /tmp with its FHS sandbox and checks for the prefix''s wineserver from the host before starting Wine, joining it with runinprefix or refusing when it lives in another sandbox, because separate invocations had started separate wineservers on one prefix; the check runs outside bwrap, whose user namespace hides other processes'' /proc entries.'
tags: [battlenet, proton, wine, bubblewrap]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-25T15:30:00-07:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/battlenet/README.md
    title: 'flakes/battlenet/README.md (one prefix, one wineserver)'
  - id: steam-package
    resource: https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/st/steam/package.nix
    title: 'nixpkgs `steam` package (`buildRuntimeEnv`, privateTmp default)'
  - id: heroic-package
    resource: https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/he/heroic/package.nix
    title: 'nixpkgs `heroic` package (privateTmp = false on the same builder)'
---

**Where:** [battlenet sub-flake](../packages/battlenet.md).

## Context

Wine runs one wineserver per prefix and finds it through a socket in
`/tmp/.wine-$UID/server-<dev>-<inode>`, named after the prefix directory.
`steam.buildRuntimeEnv` gives every sandbox a private `/tmp` by
default.[^steam-package] On 2026-10-25 that went wrong in three ways. A
`battlenet` started before `nrs` and one started after it each ran their own
wineserver on nebula's prefix, so there were two Battle.net windows and two
registries being written. `battlenet kill` couldn't see either server. The
older instance, built without 32-bit FreeType, showed a blank "Battle.net
Error" dialog and a black window. Its main thread was a zombie, but 53 live
threads kept the window open after its wineserver had gone. The umu entry,
which runs in its own sandbox, could produce the same collision.

## Decision

- **Share the host's `/tmp`** (`privateTmp = false`), as nixpkgs' Heroic does
  with the same builder.[^heroic-package] Every invocation then reaches the
  same wineserver.
- **Check for the prefix's wineserver before starting Wine.** A wineserver's
  working directory is its socket directory, so `/proc` finds it from any
  mount namespace. If its `/tmp` is ours, the new invocation joins with
  Proton's `runinprefix`, which skips prefix setup (`waitforexitandrun` would
  block until the running session ended). Otherwise it refuses. `install`
  needs the prefix idle, and a lock covers the window before the first
  wineserver exists.[^subflake-readme]
- **Run that check on the host.** Inside bwrap's user namespace the kernel
  denies reading other processes' `cwd` and `environ`. `[ -O ]` still passes,
  so the scan silently found nothing. The launcher is therefore split:
  `battlenet` (host: detection, join or refuse, `kill`) and `battlenet-proton`
  (sandbox: Proton's environment, installer, the chosen verb).
- **The invocation that starts the session owns it.** Wine puts its programs
  in sessions of their own, so a terminal Ctrl-C reached only Proton's Python
  wrapper, which died with `KeyboardInterrupt` while Battle.net ran on. The
  owner runs Proton as a background job, which a non-interactive shell starts
  with SIGINT ignored. It traps INT, TERM and HUP: it kills its own child tree
  (so Proton can't spawn more Wine mid-setup), then stops the prefix.
  Joiners don't own the session.
- **`kill` works across sandboxes.** It sends each wineserver SIGTERM, which
  saves the registry, and then SIGKILLs every process whose `WINEPREFIX` is
  the prefix. It reads each thread's environment, because a zombie main
  thread's own environment is unreadable.

## Consequences

Tested on a throwaway prefix on 2026-10-25:

- A second `run` joined the first session in 1 s.
- `install` was refused while a session ran.
- A `steam-run` session on the same prefix, which has a private `/tmp`, was
  detected as foreign and refused.
- `kill` stopped both sessions (2 wineservers, 18 processes).

Ctrl-C tests, in a process group with default SIGINT handling as a terminal
would give, both exited 130 with no traceback and no Wine left: once with Wine
running, and once one second in, during prefix setup. On nebula's live prefix,
a second `battlenet` left one wineserver and one window. A Ctrl-C in a herdr
pane closed Battle.net in about 3 s (1 wineserver, 17 processes). Running the umu entry and this launcher on one prefix at the same time
is now refused rather than corrupting it.

[^subflake-readme]: `flakes/battlenet/README.md`: one prefix, one wineserver
[^steam-package]: nixpkgs `steam` package: `buildRuntimeEnv` (`privateTmp ? true`)
[^heroic-package]: nixpkgs `heroic` package: `privateTmp = false`
