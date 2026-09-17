---
name: herdr-pane-run
description: Run a command in ANOTHER herdr pane and get back just that command's output - use whenever the work needs a shell you do not own, most often an ssh session a human already opened in a neighbouring pane (a tenant VM, a bastion host, a jump box, a remote you cannot authenticate to yourself). Also use when a naive `herdr pane run` + `herdr pane read` returned the login banner, a half-finished command, or nothing at all. Triggers on "run it in my ssh pane", "the session is open in the other pane", "use the pane I already logged in on", "check that on the box", scraping pane output, or driving a read-only investigation on a host reachable only through an existing pane.
---

# Running commands in another herdr pane

## When this applies

You are in a herdr session, and the shell you need is in a **different pane** —
typically an ssh session a human already authenticated (Azure Bastion + AAD,
a VPN-only jump box, an MFA'd bastion). Re-establishing that connection
yourself is slower, sometimes interactive, and occasionally impossible. Borrow
the session instead.

Find the pane with `herdr pane list` — it is JSON; the `terminal_title` of an
ssh pane usually shows `user@host`, and `pane_id` (e.g. `w2V:p1`) is what you
pass. Panes running an agent have `"agent": "claude"`; do not type into those.

## Use the wrapper

```sh
~/.claude-work/skills/herdr-pane-run/assets/herdr-pane-run <pane-id> '<command>'
```

```sh
# examples
herdr-pane-run w2V:p1 'uptime; df -hT | grep -v tmpfs'
HPR_LINES=2000 herdr-pane-run w2V:p1 'sudo grep -c ERROR /var/log/syslog'
HPR_TIMEOUT=300 herdr-pane-run w2V:p1 'sudo du -sh /var/lib/something'
```

It prints the command's output on stdout, `herdr-pane-run: exit=N` on stderr,
and exits with the command's own status. Quote the command so your shell does
not expand it — it runs in the pane, which may be on another host.

Env: `HPR_TIMEOUT` (default 90 s — keep it under your own tool timeout),
`HPR_LINES` (default 500 scrollback lines; raise for chatty commands).

## Why not raw herdr calls

A pane is a teletype, not an API, and three things bite:

1. **No completion signal.** `herdr pane run` returns when the keystrokes are
   delivered, not when the command finishes. Read immediately after and you get
   a half-finished command — on a `grep` over a multi-hundred-MB log, nothing at
   all.
2. **No output boundaries.** `herdr pane read` returns the whole visible
   scrollback: Ubuntu MOTD, "111 updates can be applied immediately", the
   previous command, shell prompts.
3. **No exit status.** A terminal hands back text, never a return code.

The wrapper fixes all three with a per-call random sentinel: it runs
`<cmd> ; echo "<sentinel> rc=$?"`, waits for a line that is exactly the
sentinel, slices the scrollback between the echoed command and that line, and
parses `rc=` back out.

## Gotchas that cost real time

- **Use `--regex "^SENT"`, never `--match SENT`.** A substring match also
  matches the *echoed command line* (which contains the sentinel), so the wait
  returns instantly, before the command has run. This is the single most
  expensive mistake here — it looks like the command produced no output.
- **Do not poll with `sleep`.** The Claude Code harness blocks foreground
  sleep-polling, and a busy retry loop will burn a tool call until it is killed.
  Let `herdr pane wait-output` do the blocking.
- **Read with `--source recent-unwrapped`.** Wrapped long lines are rejoined,
  so `grep`/`awk` do not see tokens split mid-path.
- **One command per call.** Chain with `;` inside a single invocation rather
  than issuing several calls into the same pane; interleaved sentinels are
  ambiguous.
- **Randomise the sentinel per call** (the wrapper does). A repeated command
  otherwise matches the previous run's marker still in the scrollback.

## Operating in someone else's session

The pane belongs to a human and often points at production.

- Default to **read-only** commands. State plainly which commands mutate, and
  get explicit approval before any that do.
- Never restart a service, kill a process, or take a host offline on your own
  initiative.
- Prefer `sudo` on a single command over opening an interactive root shell —
  it keeps the pane's state predictable for its owner.
- Long or noisy output: write it to a file on the host and pull out just what
  you need, rather than flooding the pane the human is watching.
- Leave the pane at a clean prompt. Do not start pagers, editors, or `htop`;
  they swallow the sentinel and strand the session in a full-screen program.

## Other agents: inspecting and driving them

`herdr-detect` reports agents in other workspaces with their live status,
blocked ones first, because a blocked agent is waiting on a human right now:

```
agents elsewhere:
  w2Q:p1   blocked  HCC-2682   <- waiting for input
  w2P:p2   idle     Image #1
```

Status comes from `herdr pane list` (no extra call): `idle`, `working`,
`blocked`, `done`, `unknown` - the same set `herdr agent wait --until` accepts.
`blocked` is the one that means a prompt or permission dialog is sitting
unanswered. What an agent is working on is its terminal title, which for Claude
is the session's own topic line, so it is descriptive but not authoritative.

**herdr does not report sub-agents.** Neither `herdr agent list` nor
`herdr pane list` has a field for them - an agent running five subagents looks
exactly like one that is not. To learn that, ask the agent.

Two channels reach another agent, and they are not interchangeable:

| Want | Use |
|------|-----|
| Message another **Claude** session as a peer | the harness's `ListAgents` + `SendMessage` (names like `p4c-docs-fd`, proper delivery, subject to `crossSessionInbound`) |
| Inspect or drive **any** agent pane, Claude or not | `herdr agent list` / `get` / `read` / `wait`, and `herdr agent prompt` to submit a prompt |

Prefer `SendMessage` for Claude-to-Claude: it is a real message, not keystrokes
into a TUI, and the recipient's settings govern whether it lands. Reach for
`herdr agent prompt` when the target is not a Claude session, or is not
registered as a peer.

Etiquette, since these are someone's running sessions:

- `herdr agent list` / `read` / `wait` are read-only. Use them freely.
- `herdr agent prompt` and `send-keys` put words in someone else's session.
  Confirm with the human first unless they have already told you to drive it.
- Never send keys to an agent whose status is `working` - you will interleave
  your input with whatever it is mid-turn.
- `herdr agent wait --until idle --timeout <ms>` is the right way to wait for a
  peer to finish. Always pass `--timeout`; without one it waits forever.

## Am I even under herdr? (`herdr-detect`)

A SessionStart hook runs this automatically, so a session normally starts already
knowing. Run it by hand if that context is missing or stale (panes opened or
closed mid-session):

```sh
~/.claude-work/skills/herdr-pane-run/assets/herdr-detect
```

```
herdr: yes - this pane w2V:p2 (workspace w2V, tab w2V:t1)
sibling panes in this workspace:
  w2V:p1   tab t1   ssh?         user@some-host: ~
  w2V:p3   tab t1   shell        (repo-name)
```

Modes: no argument = the summary above (exit 0 under herdr, 1 if not);
`--quiet` = exit status only; `--hook` = SessionStart hook contract, printing
nothing and always exiting 0 when not under herdr, so session start never fails.

Scope: every pane in the **current workspace** (all its tabs), plus a one-line
roll-up of the other workspaces with pane counts and a count of likely-ssh panes
in each. herdr's tree is session -> workspace -> tab -> pane; there is no
"space" or "window" level. If the roll-up shows an `ssh?` pane in another
workspace, get its id from `herdr pane list` and drive it the same way - a pane
id works across workspaces, nothing has to be focused first.

Detection itself is just environment: herdr exports `HERDR_ENV=1`,
`HERDR_PANE_ID`, `HERDR_TAB_ID`, `HERDR_WORKSPACE_ID` and `HERDR_SOCKET_PATH`
into every pane, and those survive into subprocesses. The script exists for the
inventory, not the yes/no — `herdr pane list` returns a large JSON blob covering
every workspace, and reading it raw costs far more context than the handful of
lines that matter.

The `ssh?` label is a heuristic: an `@` in the terminal title. Confirm with a
cheap `hostname` through `herdr-pane-run` before assuming which host a pane is
on.

When editing this script, keep single quotes out of the embedded `bun -e '...'`
program - the whole thing is one shell-quoted string, so a single quote (even
inside a JS template literal) closes it early. The failure is silent: `bun`
errors go to `/dev/null` and the inventory just vanishes while the header line
still prints.

Wired up in `~/.claude-work/settings.json` as:

```json
{ "type": "command",
  "command": "\"/Users/k/.claude-work/skills/herdr-pane-run/assets/herdr-detect\" --hook 2>/dev/null || true",
  "timeout": 10,
  "statusMessage": "Detecting herdr panes..." }
```
