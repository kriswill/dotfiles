---
type: Decision
title: Confine Hermes Agent on macOS with a Seatbelt Sandbox
description: 'On the macs Hermes Agent (gateway and CLI) starts through a deny-by-default Seatbelt profile from the sub-flake''s nix-darwin module, because upstream''s only macOS isolation is a container terminal backend that leaves the agent itself unconfined; the agent reads the system, writes one state directory, and keeps the open network.'
tags: [ai-agent, sandbox, darwin, sub-flake]
status: stable
generated: { by: codex/gpt-6, at: 2026-11-13T14:43:17-08:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/hermes-agent/README.md
    title: 'flakes/hermes-agent/README.md (the sandbox: what it grants, what was checked, what it does not do)'
  - id: hermes-security
    resource: https://hermes-agent.nousresearch.com/docs/user-guide/security
    title: 'Hermes Agent docs: Security (write guards, terminal backend comparison)'
---

**Where:** [hermes-agent sub-flake](../packages/hermes-agent.md),
[hermes-agent module](../modules/hermes-agent.md),
[mini-hermes-agent](../modules/mini-hermes-agent.md).

## Context

Hermes was to run on [mini](../hosts/mini.md), which also holds a
[headless signing agent](headless-git-signing-agent.md), the 1Password agent
socket, herdr and tmux servers, and k's whole home. On nebula the gateway
runs as k behind systemd's `ProtectSystem=strict`, which limits writes but
not reads ([hermes-agent-system-service](hermes-agent-system-service.md)).
launchd has no equivalent.

Upstream's own protections don't confine the agent. Its write guards cover
the file tools only, and its docs say the terminal tool "can still `cat` or
overwrite denied paths".[^hermes-security] The isolating terminal backends
(docker, modal, daytona) put the agent's shell commands in a container while
the agent, its plugins, hooks and MCP servers stay on the host; mini runs no
container runtime. Hermes is single-owner, so a separate macOS account
would also have to run the CLI.

## Decision

The sub-flake gains a nix-darwin module whose `sandbox.enable` (default on)
starts the gateway agent and every binary of the installed CLI through
`/usr/bin/sandbox-exec` with a generated profile
(`nix/darwinSandbox.nix`).[^subflake-readme]

- **Deny by default.** An allow-default profile with a few denies leaves
  Apple events, LaunchServices and launchd job submission open, and each of
  those runs code outside the sandbox. The profile allows process execution,
  system reads, a short list of mach services (name lookup, DNS, TLS trust,
  logging) and nothing else by default.
- **One writable tree.** `stateDir` (`~/.hermes-agent`) holds `HERMES_HOME`
  and the workspace and is `HOME` inside, so tools' dotfiles land there. A
  private `TMPDIR` replaces `/tmp`. Projects are opted in per path
  (`sandbox.readWritePaths`).
- **The real home is unreadable**, as are `/tmp` and other programs' temp
  directories. Metadata (`stat`) is allowed everywhere so `realpath` works.
- **Unix sockets are allow-listed.** A socket is a way into its server: a
  tmux or herdr server types into an unsandboxed pane, an ssh agent signs.
  By default, only sockets under the writable paths, mDNSResponder and syslog connect.
  The nix daemon socket is opt-in (`sandbox.unixSockets`).
- **The environment is allow-listed** (`env -i` plus named variables), so
  tokens exported in the calling shell don't reach the agent.
- **The network stays open.** Hermes needs its provider, web tools and
  messaging platforms, and Seatbelt filters by address, not by host name.

Verified on macOS 26.4.1 with the built launcher: the table in the README
lists each escape tried and its result, and the gateway, `hermes gateway
status` and the Herdr hook ran inside. Later that day a live agent on
mini (Codex login) ran its terminal and file tools against the same list,
with the same results, and Herdr showed working/idle.

Mini's subsequent host-specific exceptions change the effective authority:
it now permits its bounded desktop-driver endpoint and the existing Herdr
Core socket, with `HC_SOCKET` supplied to the CLI and gateway. Core can run
commands outside Seatbelt as k, interact with other terminals and reach
configured peers. Thus the original direct-access checks do not establish
end-to-end confinement for today's Mini. A read-only sandbox → Core → host
Git-config check succeeded after the 2026-11-13 generation-28 reboot; see
[Mini's current boundary](../modules/mini-hermes-agent.md). This delegation
does not expose the root signing token or private signing key.

## Consequences

- An agent, a malicious skill or a prompt injection can still send out
  whatever the sandbox can read: its own state (provider keys included) and
  the listed paths. Keep `readWritePaths` narrow.
- A project the agent may write is trusted the moment its hooks or build
  scripts run outside the sandbox.
- Programs that sandbox themselves (Chromium, `nix build --sandbox`) fail
  inside, since profiles don't nest. Setuid programs fail; the launcher puts
  nixpkgs' unprivileged `ps` on `PATH` because Hermes calls `ps`.
- Each launch is its own sandbox, and signals cross none. The launchd
  gateway can't stop a gateway a CLI started, so the CLI's profile is denied
  the gateway locks and only the agent can be the gateway; `hermes gateway
  stop|restart` don't work on it either (use `launchctl kickstart -k`).
- `stateDir` must be short: past about 100 bytes Hermes moves its control
  socket to `/tmp`, which the sandbox refuses.
- `sandbox-exec` is deprecated. If Apple removes it the module needs another
  mechanism; the profile language is undocumented, so every rule here was
  found by testing and should be re-tested on a major macOS upgrade.
- The NixOS module is unchanged in behaviour. It now shares the CLI wrapper
  and Herdr pieces with the darwin one (`nix/hermesCli.nix`).


[^subflake-readme]: flakes/hermes-agent/README.md
[^hermes-security]: Hermes Agent docs: Security
