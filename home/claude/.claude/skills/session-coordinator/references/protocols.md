# Coordinator protocols

Operational detail for Steps 3-5 of SKILL.md. These exist because each one replaced a failure that cost real time in a live mission.

## Spawning

Model/effort default: the strongest available model at high effort (`--model claude-opus-5 --effort high` as of 2026-07; check what's current). Teammates run `claude --dangerously-skip-permissions` — they are trusted with their own worktree and nothing else. Spawn:

```bash
scripts/spawn-teammate.sh <name> <worktree-dir> <brief-file>
```

which creates the teammate's multiplexer window — a tmux window or a herdr tab, auto-detected from `HERDR_PANE_ID`/`TMUX` — launches claude with the brief as the initial prompt, and verifies the session started processing (in herdr via `herdr agent wait --status working`, falling back to visible claude chrome for turns that finish before the poll). One teammate per window/tab; window/agent name = teammate name. Placement is pinned to the coordinator's own tmux session / herdr workspace (derived from `TMUX_PANE` / `HERDR_PANE_ID`), never the currently-active one — herdr tabs cannot be moved between workspaces after the fact. The script also preflights before spawning: it refuses a brief still containing unexpanded template placeholders and a workdir that is a primary git checkout rather than a linked worktree (`--force` overrides both).

## Messaging teammates (the delivery problem)

tmux `send-keys "<long text>" Enter` frequently leaves the text as an unsubmitted paste — paste rendering swallows the trailing Enter. In the original mission ~a third of messages needed manual rescue, and two merge-gating directives silently never started a turn. Therefore:

- **Every** coordinator->teammate message goes through `scripts/msg-teammate.sh <name> "<message>"`, which sends the text, sends Enter as a separate delayed keystroke, then verifies that a turn actually started, retrying Enter if not. It exits nonzero if delivery cannot be confirmed — treat that as undelivered. In herdr it uses `herdr agent send` + `herdr pane send-keys <id> enter` and verifies with `herdr agent wait --status working`; in tmux it verifies via capture-pane (spinner visible or message rendered in transcript). Same interface either way.
- Long content (briefs, designs, data) goes in files; the message just points at the file.
- Additionally, each teammate polls `inbox-<name>.md` between steps (this is in the brief template). For anything mission-critical, pass `--inbox <scratch>` to msg-teammate.sh — it appends the message to the teammate's inbox file *before* attempting delivery, so the directive survives even an unconfirmed send.

## Monitoring

- **Status stream** (persistent Monitor): `tail -F -n 0 <scratch>/status-*.md`, filtered of noise lines. This is your primary signal.
- **Heartbeat** (persistent Monitor): `scripts/heartbeat.sh <name>...` — polls every 2 min and emits one line per confirmed state change. It encodes the hard-won rules so you don't re-derive them: every non-working state needs 2+ consecutive reads before alerting (single-read idle/done alerts were turn-boundary races, every time); herdr status comes from `herdr agent get <name>` (`agent_status`, any non-working value reported verbatim — expect `done` besides `idle`); tmux panes classify by the *spinner line*, never the last line (that's the input box — always looks idle); a confirmed-idle pane with text in its input box (a stranded self-prompt) is auto-submitted via msg-teammate.sh's verified bare-Enter. `--no-submit` to observe only; `--once` for an undebounced triage read.
- **Idle triage**: an idle session is one of (a) legitimately waiting on its own background shells — check for "N shells" in the pane footer and the lock owner file; (b) stalled with a queued self-prompt in its input box — heartbeat.sh detects and auto-submits this; the manual tool is msg-teammate.sh with an empty message; (c) genuinely stalled — send a status-check directive. A teammate that went idle right after receiving an assignment is case (c) until proven otherwise; the original mission caught a real stall exactly this way.
- **CI watchers** (one per open PR): `scripts/ci-watch.sh <pr>` — records the armed head SHA, polls `gh pr checks --json name,bucket` every 30s, emits each check once as it settles, declares all settled verdicts VOID and re-arms if the head SHA changes mid-watch, and exits 0 all-green / 1 otherwise, printing the exact `merge-pr.sh` invocation on green. On failure, pull the specific job log (`gh api .../jobs/<id>/logs`) and grep for `##[error]` — the real error is usually at the end, and naive greps match test names containing "fail".

## Shared-machine measurement (the contamination problem)

Two teammates benchmarking one machine invalidated each other's numbers twice before the lock existed. The regime (also in every brief):

- All heavy runs go through `scripts/with-heavy-lock.sh <scratch> "<who>: <purpose>" -- <cmd...>` — the `heavy.lock` mkdir-mutex with owner file, trap-release, and stale-holder stealing (a dead holder's lock is reclaimed via atomic rename instead of stalling the mission). The wrapped command's exit code and stdout pass through.
- Process-tree-scoped samplers with per-sample contamination flags — belt and braces: the lock prevents contamination, the flag detects what the lock missed.
- Interleaved A/B arms inside one lock hold; counts distinguished from timings (counts survive contention, timings don't).
- The tell that attribution is broken: a measurement that violates a structural bound (e.g. more concurrent processes than a semaphore allows). Trust structural bounds over samplers.

## PR / merge pipeline

- Teammates open PRs; only the coordinator merges, and only through `scripts/merge-pr.sh <n> <watched-sha>` — it refuses (exit 3) if the PR head no longer matches the SHA whose checks you watched, then arms `gh pr merge --merge --auto`. Auto-merge closes the race where a teammate pushes between your check and your merge (this race happened; branch protection caught it, but the backstop is not the plan).
- A fresh push resets checks: ci-watch.sh voids its verdicts and re-arms itself on a SHA change, but a verdict carried away from a stopped watcher never transfers to a new SHA.
- Merge order when branches overlap: additive/instrumentation PRs first; the restructuring PR rebases on top. Have the rebasing teammate verify the rebase changed no measured code (`git diff <old> <new> -- src/ ...` empty) so measurements carry over without re-runs.
- Regressions do not merge, however much design work they carry. Parity doesn't either, if it adds complexity — the burden is on the change to beat the status quo on the path that matters, stated honestly (a change can lose on one path and win on the one users actually feel; the PR table must show both).

## Nix / toolchain

If the repo has `flake.nix`/`.envrc`: every build/test/lint/format command runs in the dev shell (`nix develop -c <cmd>`), because CI does — a locally-passing check outside the shell proves nothing. CI-equivalent commands belong in the briefs verbatim. For a fresh project: pick the toolchain deliberately (flake devShell if the ecosystem fits), commit it first, and make CI mirror it before feature work starts.
