---
type: Decision
title: Use hc for Agent Terminal Coordination
description: 'Move shared terminal helpers and coordinator scripts to herdr-core hc, retaining tmux support and using reported status for delivery and monitoring.'
tags: [herdr, agents, shell]
status: stable
generated: { by: codex/gpt-6, at: 2026-11-13T12:11:00-08:00 }
sources:
  - id: coordinator-protocols
    resource: ../../home/claude/.claude/skills/session-coordinator/references/protocols.md
    title: Coordinator delivery and monitoring protocols
  - id: terminal-helper
    resource: ../../home/agents/.agents/skills/hc-terminal-run/SKILL.md
    title: Shared hc terminal command helper
---

**Where:** [Herdr](../modules/herdr.md), the shared
[hc-terminal-run skill](../../home/agents/.agents/skills/hc-terminal-run/SKILL.md),
and the [session coordinator](../../home/claude/.claude/skills/session-coordinator/SKILL.md).

## Decision

Detect `HC_TERMINAL_ID` before `TMUX`. Spawn named hc terminals with the
Claude profile passed explicitly, preserve teammates across coordinator
restarts, and use `hc get` status reports for monitoring. Keep the existing
tmux path. Use `hc send` for delivery, including empty sends, so blocked
states and unfinished human drafts retain the core's protection. An
unconfirmed agent send requires inspection; do not retry it with raw Enter.
The coordinator's integration policy still controls publishing.[^coordinator-protocols]

For a configured remote machine, prefer `hc exec --on`. Borrow a terminal
only when an existing authenticated SSH session is necessary. The renamed
wrapper checks the foreground program, brackets output with split markers,
and runs the command in a subshell so `exit` and directory/environment
changes cannot alter the borrowed shell. A newline delimiter handles
commands that do not end their output with a newline. Capture returns
terminal lines, not byte-exact output; an SSH foreground process cannot
prove that its remote side is at a shell prompt.[^terminal-helper]

## Verification

Verified against hc 0.1.20. The coordinator's existing self-tests cover
status parsing, spawn preflights, stand-down checks and message delivery.
An isolated core exercises command output, nonzero status, `exit`, trailing
comments, blank output and foreground-program refusal. Regression fixtures
also verify that blocked or unconfirmed sends never fall back to raw keys.

The old per-pane usage watcher was [retired](herdr-usage-tab-indicator.md)
in the same reconciliation; usage collection remains with
[ai-usage](../packages/ai-usage.md).

[^coordinator-protocols]: Delivery, state reporting, profile forwarding and teammate lifetime.
[^terminal-helper]: Command capture boundaries and borrowed-terminal limitations.
