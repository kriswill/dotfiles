---
name: hc-terminal-run
description: Run a command in ANOTHER hc (herdr-core) terminal and get back just that command's output and exit code. Use whenever the work needs a shell you do not own, most often an ssh session a human already opened in another terminal (a tenant VM, a bastion host, a jump box, a remote you cannot authenticate to yourself). Also use when a naive `hc send` + `hc read` returned the login banner, a half-finished command, or nothing at all, and when you need to inspect or drive another agent's terminal. Triggers on "run it in my ssh terminal", "the session is open in the other tab", "use the terminal I already logged in on", "check that on the box", scraping terminal output, or a read-only investigation on a host reachable only through an existing terminal.
---

# Running commands in another hc terminal

## When this applies

Every terminal here is an hc (herdr-core) terminal: `$HC_TERMINAL_ID` is set to
your own address (`t25`). The shell you need is in a **different** terminal,
typically an ssh session a human already authenticated (Azure Bastion + AAD,
a VPN-only jump box, an MFA'd bastion). Re-establishing that connection
yourself is slower, sometimes interactive, and occasionally impossible. Borrow
the session instead.

If the host is an hc machine (`hc machine ls`: nebula, mini), skip borrowing:
`hc exec --on <machine> <argv...>` runs a program there and returns exactly its
output and exit code.

## Find the terminal

`hc ls` lists every live terminal, yours and the human's, on every connected
machine. Piped, it is JSON. `agent` is the foreground program, so an ssh
session shows as `ssh`; agents also carry a `status`.

```sh
hc ls --json | jq -r '.terminals[] | select(.status == null)
  | "\(.address)\t\(.agent)\t\(.where // .cwd)"'
hc get t3y --json | jq -r .title    # often user@host for ssh
```

Confirm the host with a cheap `hostname` through the wrapper before acting on
it. Terminals on other machines are addressed `machine/t7`. A bare name only
resolves on this machine, so use `nebula/<name>` for a remote one.

## Use the wrapper

```sh
~/.claude-work/skills/hc-terminal-run/assets/hc-terminal-run <terminal> '<command>'
```

```sh
# examples
hc-terminal-run t3y 'uptime; df -hT | grep -v tmpfs'
HCR_LINES=5000 hc-terminal-run t3y 'sudo grep -c ERROR /var/log/syslog'
HCR_TIMEOUT=300 hc-terminal-run nebula/t3y 'sudo du -sh /var/lib/something'
```

It prints the command's output on stdout, `hc-terminal-run: exit=N` on stderr,
and exits with the command's own status (2 when it refuses or cannot reach the
terminal). Quote the command so your shell does not expand it: it runs in the
target terminal, which may be on another host.

Env: `HCR_TIMEOUT` (default 90 s, keep it under your own tool timeout),
`HCR_LINES` (default 2000 history lines, raise for chatty commands). It needs
only `hc`, `jq`, `awk`, `sed` and `grep`.

It refuses your own terminal, any terminal reporting agent status, and a
foreground program other than sh, bash, zsh or ssh. For an SSH session,
confirm that the remote side is at a supported shell prompt first.

## Why not raw hc calls

A terminal is a teletype, not an API:

1. **No completion signal.** `hc send` returns once the text is typed, not when
   the command finishes. Read right after and you get a half-finished command.
2. **No output boundaries.** `hc read` returns the screen and history: MOTD,
   prompts, the previous command.
3. **No exit status.** A shell prompt hands back text, never a return code.

The wrapper groups the entire request before printing its begin marker,
runs the command in a subshell, and prints a newline-delimited end marker
with `rc=`. It waits for that marker and returns the captured output as
terminal lines (not byte-exact binary output). `exit`, `cd`, and environment
changes stay inside the subshell, preserving the borrowed shell.

## Gotchas

- **`hc wait --output` matches a plain substring**, including the echoed
  command line. The markers are split in the typed text (`"HCREND_""<id>"`) so
  only the command's own output contains them. Keep that if you edit the script.
- **`hc wait --output` only sees output printed after the wait starts.** A fast
  command can finish first. The wrapper re-reads the history between short
  waits instead of trusting a single wait. Never sleep-poll: let `hc wait` block.
- **One command per call.** Chain with `;` inside one invocation. Interleaved
  calls into the same terminal make the markers ambiguous.
- **Keep work in the foreground.** A command ending in `&` returns before
  its background work completes; that later output is outside the capture.
- **sh, bash or zsh only.** fish spells `$?` as `$status`, so no exit code
  comes back.
- **A timed-out command is still running in the terminal.** Calling again types
  ahead of it. Check `hc read <t>` and wait for the prompt first, for example
  `hc wait <t> --output '<last line it prints>'`.
- **`hc send` waits for a person's unfinished draft** (up to `draft_wait`,
  60 s by default). If the human is typing in that terminal, the call stalls.

## Operating in someone else's session

The terminal belongs to a human and often points at production.

- Default to **read-only** commands. Say plainly which commands mutate, and
  get explicit approval before any that do.
- Never restart a service, kill a process, or take a host offline on your own
  initiative.
- Prefer `sudo` on a single command over opening an interactive root shell.
  It keeps the terminal's state predictable for its owner.
- Long or noisy output: write it to a file on the host and pull out just what
  you need, rather than flooding the terminal the human is watching.
- Leave the terminal at a clean prompt. Do not start pagers, editors or `htop`:
  they swallow the marker and strand the session in a full-screen program.

## Other agents: inspecting and driving them

`hc ls` shows each agent's `status`: `idle`, `working`, `blocked`, `done`,
`error`. It comes from the program's own OSC 7501 reports; never infer it from
screen text. `blocked` means a prompt or permission dialog is waiting on a
person. Sub-agents carry a `parent` address.

| Want | Use |
|------|-----|
| Message another **Claude** session as a peer | the harness's `ListAgents` + `SendMessage` |
| Inspect any agent | `hc get <t>`, `hc read <t> --lines 100` (read-only) |
| Drive any agent | `hc send --if idle <t> "<text>"`, then `hc wait <t>` |

Prefer `SendMessage` for Claude-to-Claude: it is a real message, not keystrokes
into a TUI. Etiquette, since these are someone's running sessions:

- `hc ls`, `get`, `read` and `wait` are read-only. Use them freely.
- `hc send` and `hc keys` put words in someone else's session. Confirm with the
  human first unless they have already told you to drive it.
- Use `--if idle` so nothing is typed into an agent mid-turn. Never use
  `--force` to get past a `blocked` agent: that answers its permission dialog.
- `hc wait <t>` returns when it stops working; a `timeout` reason is a
  check-in, not a failure.
