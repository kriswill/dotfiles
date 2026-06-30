# codebase-memory-mcp — launchd supervision (nix-darwin)

A nix-darwin module plus two small C tools that run
[`codebase-memory-mcp`](https://github.com/DeusData/codebase-memory-mcp) as a
supervised background daemon on macOS, with a CLI to drive it.

The MCP server itself — the C binary with its embedded 3D graph UI — is built by
`../package.nix`. **This directory is only the macOS supervision layer.**

## Why a wrapper is needed

`codebase-memory-mcp` has no daemon mode. Its HTTP graph UI (default port 9749)
and git-watcher run as background threads of the **stdio MCP server**, which
blocks until stdin hits EOF (or SIGTERM). Under launchd stdin is `/dev/null` →
instant EOF → the process exits at once.

`cbm-daemon` fixes that: it opens a FIFO read-write (so a writer is always held
and the read loop never sees EOF), dup2's it onto stdin, and execs the server in
the **foreground**. launchd then tracks the real PID directly — `KeepAlive`
restarts it on crash, and `bootout` / `kickstart -k` reach the server's own
graceful SIGTERM handler.

## Contents

- **`cbm-daemon.c`** — the launchd `ProgramArguments` wrapper above.
- **`cbm-ctl.c`** — control CLI (below).
- **`package.nix`** — compiles both into the `cbm-tools` package; tool paths
  (`codebase-memory-mcp`, `git`, `launchctl`, …) are baked in via `-D`, so the
  binaries rely on nothing in `PATH`.
- **`module.nix`** — the nix-darwin module, exported as
  `darwinModules.codebase-memory-mcp`.

## Usage

Enable per host:

```nix
# in a host module, e.g. modules/hosts/<host>.nix
kriswill.codebase-memory.enable = true;
```

This puts `codebase-memory-mcp` + `cbm-ctl` on `PATH` and registers a launchd
user agent **`org.nixos.codebase-memory-mcp`** (`KeepAlive`, runs at load,
background / low-priority I/O). Logs:
`~/Library/Logs/org.nixos.codebase-memory-mcp.{out,err}.log`.

| Option | Default | |
|---|---|---|
| `kriswill.codebase-memory.enable` | `false` | the agent + tools |
| `kriswill.codebase-memory.package` | this flake's build | package to supervise |
| `kriswill.codebase-memory.port` | `9749` | HTTP UI / daemon port |

Requires `system.primaryUser` (used for the per-user log paths).

### `cbm-ctl`

| Command | Does |
|---|---|
| `status` | launchd state, port listener, indexed projects |
| `flush [path]` | persist the index artifact for a repo |
| `commit [-m msg] [path]` | flush, then `git add`/`commit` `.codebase-memory` |
| `start` · `stop` · `restart` | control the launchd agent |
| `logs` | `tail -F` the daemon logs |

`flush`/`commit` take a `mkdir`-atomic advisory lock so concurrent sessions
serialize heavy reindexing instead of piling on. (DB integrity is already
handled by the daemon's SQLite WAL + `busy_timeout`; the lock only avoids
redundant work and guards the git commit.)

## Build

```
nix build .#cbm-tools
```

aarch64-darwin only (launchd agent + tools are macOS-specific).
