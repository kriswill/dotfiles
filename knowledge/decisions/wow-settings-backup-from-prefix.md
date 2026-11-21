---
type: Decision
title: Back Up WoW Settings from the Launcher's Prefix, One Repository per Client
description: 'programs.battlenet.wowBackup commits each WoW client''s WTF, Fonts and Interface folders to a git repository whose .git lives outside the game folder, on a user timer. The client folder is found from the launcher''s prefix on every run, because a path stored only in the repository went stale when the prefix moved and backups failed for 27 days.'
tags: [battlenet, wow, backup, git, systemd]
status: stable
generated: { by: claude-code/fable-5.2, at: 2026-11-20T23:20:00-08:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/battlenet/README.md
    title: 'flakes/battlenet/README.md, "Backing up WoW settings" (what is backed up, how, by hand)'
  - id: git-config
    resource: https://git-scm.com/docs/git-config
    title: 'git-config (core.worktree: a work tree away from the repository)'
  - id: gitignore
    resource: https://git-scm.com/docs/gitignore
    title: 'gitignore ($GIT_DIR/info/exclude: ignore rules kept out of the work tree)'
  - id: systemd-unit
    resource: https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html
    title: 'systemd.unit, "Unit File Load Path" (user units: ~/.config, then /etc, then $XDG_DATA_HOME)'
---

**Where:** [battlenet](../packages/battlenet.md)
(`battlenet-wow-backup.sh`, `programs.battlenet.wowBackup`); enabled on
[nebula](../modules/nebula-battlenet.md) for `_retail_` and `_forever_`.

## Context

Since June 2026 nebula backed up the retail client's settings with a
hand-made setup outside the dotfiles: a git repository in
`~/src/wow-settings` whose work tree was the `_retail_` folder
(`core.worktree`),[^git-config] a `backup.sh` beside it, and a `wow-backup`
user timer in `~/.config/systemd/user`. The design is sound. Battle.net locks
and rewrites files in the game folder, so nothing may live there, and the
"only WTF, Fonts and Interface" rule sits in the repository's
`info/exclude`.[^gitignore]

Its weakness was the path. The client's folder was written into the
repository's config (and again into an `.envrc`), nowhere near the launcher's
`prefix`. On 2026-10-25 the prefix
[moved out of Steam](../modules/nebula-battlenet.md). Every run since failed
with `fatal: Invalid path`. The unit showed failed, nobody looked, and
nothing was backed up until 2026-11-20. A second client, `_forever_`, had no
backup at all.

## Decision

`battlenet-wow-backup`, in the battlenet package, run by a declared user
timer:

- **One repository per client**, laid out as before: work tree in the game
  folder, `.git` wherever `wowBackup.clients` says, rules in `info/exclude`.
  A repository that doesn't exist is created on the first run, so a new
  client is one line.
- **The client folder comes from `programs.battlenet.prefix` on every run**,
  the same resolution the launcher does, and is written back to the
  repository's `core.worktree` so plain `git -C REPO` keeps working. The
  launcher and the backup can't disagree about where the game is.
- **A user unit, a oneshot.** Commits use the player's git identity and
  signing. A client that fails doesn't stop the others, and the unit ends
  failed. A configured client whose folder is missing is a failure; a user
  with no prefix and no repositories is skipped quietly. It sets
  `restartIfChanged = false` and a 10-minute start timeout, so a switch never
  waits on a backup in flight
  ([decision](user-oneshots-skip-switch-restart.md)).
- **The unit keeps the name `wow-backup`.** The journal history continues,
  and the hand-made units could be moved to `~/.local/share/systemd/user`,
  which `/etc/systemd/user` outranks,[^systemd-unit] so the declared units
  took over at the switch with no gap and no double run.

Rejected:

- **One repository for the whole install.** It would rewrite every path in
  98 commits of retail history (`WTF/…` to `_retail_/WTF/…`). The two clients
  share 3 of 17 addon folders, so little would be saved.
- **Tracking the repositories in the dotfiles.** They hold about 2 GB of game
  files and saved variables with account names.
- **A system unit.** It would need the user's git identity and signing agent
  handed to it.

## Consequences

Moving the prefix now means changing one option; the backups follow. The
repositories have no remote, so the history exists only on nebula's
disk.[^subflake-readme]

- The first `_forever_` snapshot (2026-11-20) was 4,836 files, a 394 MB
  repository. Retail's is 1.5 GB after 99 commits. Addon updates are most of
  each commit.
- `~/src/wow-settings/backup.sh` and
  `~/.local/share/systemd/user/wow-backup.*` are leftovers once the declared
  units run, and can be deleted.
- A `wow-backup` unit in `~/.config/systemd/user` would outrank the declared
  one again.

[^subflake-readme]: `flakes/battlenet/README.md`, "Backing up WoW settings"
[^git-config]: git-config, `core.worktree`
[^gitignore]: gitignore, `$GIT_DIR/info/exclude`
[^systemd-unit]: systemd.unit, the user unit search path table
