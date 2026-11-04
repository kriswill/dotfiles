---
type: Decision
title: Report Hermes to Herdr from a CLI Wrapper and a Gateway Shell Hook
description: 'services.hermes-agent.herdr.enable is now two TypeScript scripts on bun instead of herdr''s generated Python plugin, which read the pane from its own environment while every Hermes hook runs in the gateway service and never fired: a hermes CLI wrapper marks the pane''s pty, and a consented gateway shell hook maps the session to that pty and reports to the Herdr app (OSC 7501) or the Herdr TUI (report-agent-session).'
tags: [hermes-agent, herdr, ai-agent]
status: stable
generated: { by: claude-code/opus-5-5, at: 2026-11-01T15:25:00-08:00 }
sources:
  - id: hermes-hooks
    resource: https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks
    title: 'Hermes Agent docs: Event Hooks (shell hooks, consent model)'
  - id: shell-hooks-py
    resource: https://github.com/NousResearch/hermes-agent/blob/v0.22.5/agent/shell_hooks.py
    title: 'hermes-agent agent/shell_hooks.py (payload, allowlist, ~30 s resync)'
  - id: terminal-breadcrumbs-py
    resource: https://github.com/NousResearch/hermes-agent/blob/v0.22.5/hermes_cli/terminal_breadcrumbs.py
    title: 'hermes-agent hermes_cli/terminal_breadcrumbs.py (tty-keyed session breadcrumbs)'
  - id: herdr-core-42
    resource: https://github.com/herdrdev/herdr-core/issues/42
    title: 'herdrdev/herdr-core#42: status from agent hooks never reaches the pane (no tty)'
  - id: subflake-readme
    resource: ../../flakes/hermes-agent/README.md
    title: 'flakes/hermes-agent/README.md (the module''s changes: herdr.enable)'
---

**Where:** [hermes-agent](../modules/hermes-agent.md) (the sub-flake's
module, `flakes/hermes-agent/nix/herdr/`), turned on by
[nebula-hermes-agent](../modules/nebula-hermes-agent.md); reports to the
panes of [herdr](../modules/herdr.md)'s TUI and its Herdr app.

## Context

`herdr.enable` used to build herdr's own Hermes integration
(`herdr integration install hermes`) and link it as the
`plugins/herdr-agent-state` Python plugin. That plugin reads the pane
(`HERDR_PANE_ID`, the socket) from its own process environment. But the
`hermes` CLI is a client of the gateway, the `hermes-agent` system service
([why a system service](hermes-agent-system-service.md)), and every hook
runs there, with neither the pane's environment nor its terminal. It never
fired.

The Herdr app adds a second problem. herdr-core takes agent status only as
OSC 7501 in the pane's own output, and a hook process has no tty to write it
to.[^herdr-core-42] Hermes plugins are Python loaded into the gateway, but a
shell hook is any program, given the event as JSON on stdin.[^hermes-hooks]

## Decision

Two scripts, TypeScript on bun, with shared helpers in `common.ts`:

- **`cli.ts` is the `hermes` CLI** (makeWrapper'd bun in front of the real
  one). For an interactive chat in a Herdr pane it writes a marker,
  `$HERMES_HOME/herdr-panes/dev-pts-N.json`, holding its pid, the pty and the
  pane ids. In a Herdr app pane it also writes `state=idle` at launch, so the
  Agents list shows Hermes before the first prompt, and `state=clear` at
  exit, since herdr-core otherwise keeps a status until the shell exits.
  Subcommands and one-shot flags run untouched.
- **`hook.ts` is a gateway shell hook** on seven events (session
  start/reset, pre/post LLM call, loop stopped, human input
  requested/resolved). It maps the session id to a pty through the CLI's own
  terminal breadcrumbs, `terminal-sessions/tty-dev-pts-N`,[^terminal-breadcrumbs-py]
  then to a live marker. It writes OSC 7501 working/idle/blocked straight to
  the pty (Herdr app), or runs `herdr pane report-agent-session` with the
  pane's socket (Herdr TUI). A session with no live marker reports nothing.
- **Consent is declared.** Shell hooks run only once approved per
  `(event, command)` in `shell-hooks-allowlist.json`.[^shell-hooks-py]
  Activation approves exactly this build's hook, drops earlier builds'
  approvals, and removes the old plugin link. The gateway rereads the
  allowlist about every 30 s. `hooks_auto_accept: true` would approve every
  configured hook, not just ours.
- **`herdr.package` is gone**: nothing runs herdr at build time any more. The
  option asserts `addToSystemPackages`, since the wrapper is what marks the
  pane. The build transpiles both scripts, so a syntax error fails it.

## Consequences

- The Ink TUI in v0.22.5 did not write the classic CLI's terminal breadcrumbs.
  Its pane marker and launch-time idle status could therefore be correct while
  every subsequent hook silently missed the pane. The local
  [TUI patch](../../flakes/hermes-agent/nix/tui-terminal-breadcrumbs.patch)
  subscribes to committed UI state, not unaccepted RPC responses, and the
  [TypeScript writer](../../flakes/hermes-agent/nix/tui-breadcrumbs/terminalBreadcrumbs.ts)
  atomically records the durable session id after attachment or compaction.
  It honors the local continuation gate and never routes explicit remote
  gateway session ids into the local continuation store. Regression tests run
  in the Nix TUI build. Verified on 2026-11-04: a freshly built TUI in a
  throwaway Herdr pane wrote its own breadcrumb, and replayed hook events
  changed the pane from idle to working and back; exiting cleared its status.
  After deployment, a pet Hermes in the real tab also verified automatic
  idle/working/idle transitions on a terminal call, blocked/question on
  clarification, and working/idle after answering, without synthetic hooks.
- Desktop, messaging, cron, subagents and a CLI outside Herdr report
  nothing, because they have no live marker.
- It leans on Hermes internals: the breadcrumb naming, the hook payload and
  the allowlist format. Re-check them on every Hermes bump.
  `session.terminal_continue` (default on) must stay on, or there are no
  breadcrumbs.
- `pkgs.herdr`'s overlay was kept only for the removed `herdr.package`
  ([umbrella decision](herdr-umbrella-subflake.md)), so it was removed in a
  follow-up.
- Verified after the switch on 2026-11-01: the gateway logged all seven
  hooks registered, the allowlist holds exactly them, and
  `plugins/herdr-agent-state` is gone.[^subflake-readme]
  Landed in commit `1d1109d`.

[^hermes-hooks]: Hermes Agent docs: Event Hooks, the shell-hook section and its consent model
[^shell-hooks-py]: hermes-agent `agent/shell_hooks.py`: the stdin payload, `shell-hooks-allowlist.json`, and `sync_from_config` (about every 30 s)
[^terminal-breadcrumbs-py]: hermes-agent `hermes_cli/terminal_breadcrumbs.py`: `get_terminal_id`, `_sanitize`, and the `session.terminal_continue` gate
[^herdr-core-42]: herdrdev/herdr-core#42: status from agent hooks never reaches the pane
[^subflake-readme]: `flakes/hermes-agent/README.md`: the module's changes, `herdr.enable`
