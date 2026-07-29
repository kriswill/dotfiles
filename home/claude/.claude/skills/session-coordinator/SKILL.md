---
name: session-coordinator
description: Run a multi-agent engineering mission as the COORDINATOR of subordinate claude sessions in tmux windows or herdr tabs (auto-detected from the multiplexer this session runs inside). Use this whenever the user wants to lead a team, spawn teammates/subordinates/workers in tmux or herdr, coordinate parallel claude sessions on a large objective, run a "mission" with implementer/validator roles, or asks for a coordinated optimize-migrate-audit-build effort that is too big for one session. Trigger even if the user just describes a big objective plus words like "team", "coordinator", "tmux workers", "herdr workers", "spawn agents in tmux", or "run this like last time's coordinated session". The argument is the mission objective; the skill molds it, pushes back if it is vague, then runs the full spawn -> execute -> validate -> report -> retrospective lifecycle.
---

# session-coordinator

Lead a small team of subordinate `claude` sessions — each in its own multiplexer window (tmux window or herdr tab; the scripts detect which multiplexer this session is inside via `HERDR_PANE_ID`/`TMUX`) and git worktree — through a substantial engineering mission: baseline, implement, independently validate, merge green PRs, produce a session report, then run a retrospective that improves this skill itself.

This skill was distilled from a real coordinated session (6 PRs, 1.7-3.1x measured speedups, three self-caught bad claims). Its core belief: **every number and claim that ships must survive something built to kill it** — a control, a lock, a byte-diff, a skeptical teammate. Build that apparatus first and the mission mostly steers itself.

## Step 0 — Read the lessons file

Read `LESSONS.md` in this skill's directory before anything else. It is the accumulated experience of prior missions and may override or extend anything below. If it names a pitfall relevant to today's mission, plan around it from the start rather than rediscovering it.

## Step 1 — Parse and mold the objective

The invocation argument is the mission objective. Before spawning anything, test it against these questions:

- **Deliverable**: what artifact/state exists at the end that doesn't now?
- **Target**: which repo/system, and what is the *substantial real thing* final validation runs against (not just fixtures)?
- **Constraints**: what must not change (data formats, public APIs, user-visible behavior, compatibility)?
- **Done-condition**: how do we know it worked — a measurement, a passing suite, a shipped artifact?
- **Integration policy**: may the team touch GitHub at all? push branches? open PRs? who merges — you automatically, or nobody until the user approves each PR (their adversarial review may run in a separate session)? Record the answer in `$SCRATCH/mission-policy` as one of `no-github` / `local-merge` / `push-only` / `prs-user-merge` / `prs-auto-merge`; spawn-teammate.sh refuses briefs that don't declare it, merge-pr.sh enforces it.
- **Budget/scale hints**: PR granularity, how autonomous, anything explicitly out of scope?

The integration policy is exempt from the two-question threshold below: if the objective doesn't state it, **ask** — never assume PRs are welcome (a mission once opened PRs and merged to main against an explicit "no PRs"; the user's constraint outranks every pipeline convenience). If the user genuinely cannot be asked, assume `push-only`.

If two or more of these are unanswerable from the objective plus quick repo inspection, **push back before spawning**: tell the user what's ambiguous, propose your best-guess interpretation, and ask focused questions (AskUserQuestion works well — offer concrete options, not open-ended "what do you want?"). A vague objective multiplied across several autonomous teammates becomes expensive drift; five minutes of molding is the cheapest optimization of the whole mission. When the objective is clear, restate it in one paragraph as the mission charter and proceed — don't interrogate a user who was already precise.

## Step 2 — Recon before roles

Spend 10-15 minutes solo before designing the team:

1. **Toolchain**: check for `flake.nix` / `.envrc`. If present, all build/test/lint commands run through the dev shell (`nix develop -c ...` or direnv). If this is a fresh project, establish tooling first (a flake devShell if the ecosystem fits, otherwise the ecosystem's standard) — a teammate can do this as step one, but the *decision* is yours.
2. **CI gates**: read the workflow files now. Coverage bars, ratchets, formatters, linters, required checks — write them into every brief so first CI runs pass. Predictable CI failures are pure waste.
3. **Invariants**: find the tests/properties that protect what must not change (determinism suites, golden files, schema tests). If the mission touches data-producing code and no output-equivalence check exists, creating one becomes an early work item — it is what makes aggressive change safe.
4. **Baseline**: measure the current state yourself (one timing run, one build, whatever fits). You cannot direct priorities without a number, and `time` + a CPU% is often enough to set the whole agenda.
5. **Real input**: ask "can the real artifact/input exist NOW?" — if the mission consumes real data, make enabling it the first user request of the mission, before implementers design from documentation. Ground truth has refuted a canonical-looking reference, corrected a spec, and fixed fixtures within minutes of existing.
6. **Journal**: create `JOURNAL.md` in your scratchpad now. Append at every event worth remembering: baselines, assignments, commits, CI verdicts, corrections, rulings, blockers, merges. It becomes the session report and feeds the retrospective — nothing gets retconned, corrections are appended not edited.

## Step 3 — Design the team

Size the team to the mission — one teammate for a focused task, several for a broad one. There is no fixed limit, but every teammate is real cost (tokens, machine contention, coordination attention), so each must have a distinct, largely-independent charter. Two roles are non-negotiable when the mission makes measurable claims:

- **Implementer(s)** — build the thing, red->green TDD, one commit per step.
- **Independent validator** — owns fixtures, measurement, equivalence checking, and A/B verdicts. The implementer never grades their own work. The validator builds its kit (fixtures, censuses, diff tooling, a rehearsed **negative control** — same binary/input on both arms must FAIL the improvement check) *while* the implementer designs, so validation never blocks on tooling.

A third role earns its cost on security-adjacent or high-stakes missions:

- **Adversarial reviewer** (optional) — review-only, no git-write authority; every verdict mutation-backed; holds a MERGE-OK gate per PR and right-of-refutation on the final report. In its first outing every vacuous guard fell to this role — none to CI or the code's authors.

Each teammate gets its own git worktree (`git worktree add ../wt/<name> -b <branch>`) and multiplexer window (tmux window / herdr tab). Verify every factual claim in a brief against the code before sending — a wrong "the crate is sync" costs a teammate its first half hour. Read `references/mission-prompt.md` and instantiate it per teammate; read `references/protocols.md` for the spawn command, communication protocol, and measurement regime that go into every brief.

## Step 4 — Spawn and wire up monitoring

Spawn with `scripts/spawn-teammate.sh`; send all later messages with `scripts/msg-teammate.sh` (it handles the paste/Enter delivery failure that plagued the original session and verifies a turn actually started — never raw `send-keys` for anything that matters). Then arm:

1. **Status stream**: teammates append one-line updates to `status-<name>.md` after every step via `scripts/log-status.sh` (stamps time + HEAD SHA deterministically — the brief template mandates it); you monitor with a persistent `tail -F` Monitor.
2. **Heartbeat**: `scripts/heartbeat.sh <names...>` as a persistent Monitor — debounced per-teammate state changes (herdr agent status / tmux spinner line) with auto-submit of stranded input-box prompts. Trust its debounce; investigate any idle that survives it.
3. **CI watchers**: `scripts/ci-watch.sh <pr>` per open PR — emits each settled check once, voids the verdict and re-arms if the head SHA moves, exits when all settle. Watch CI as events, not by polling in your main loop.

Status updates to the user at every milestone and for anything taking longer than ~5 minutes. Lead with what happened, not what you're about to do.

## Step 5 — Execute: the coordinator's discipline

You coordinate; teammates implement. Your jobs during execution:

- **Design review before code.** Require investigation-first: a written design with a hazard list, posted to the status file, signed off by you. For performance designs, require the arithmetic: projected saving *after* dividing by pool width and measured efficiency. If the arithmetic isn't there, send it back — the original session's only perf regression was exactly the design that skipped this.
- **Adjudicate with artifacts.** When teammates disagree on a root cause, the claim that cites the artifact wins; the author of the code gets right of reply before anyone acts on a diagnosis of it. Be willing to withdraw your own directives — the coordinator being wrong quickly is far cheaper than being wrong stubbornly.
- **Hold the equivalence gate.** Any change to output-producing code merges only with proof the output is equivalent (byte-identical modulo listed volatile fields, or the project's nearest analog), verified by the validator on the real target.
- **Enforce measurement hygiene** (details in `references/protocols.md`): exclusive lock for heavy runs, tree-scoped attribution, named metrics, interleaved arms, counts vs timings distinguished. Every published number states its methodology.
- **Merge discipline**: teammates open PRs with honest trade-off tables (every context measured — wins AND costs — in the first paragraph); only you merge, and only what the integration policy allows: `scripts/merge-pr.sh <n> <watched-sha> --policy $SCRATCH/mission-policy` refuses without a declared policy, refuses under `no-github`/`local-merge`/`push-only`, requires the user's per-PR approval under `prs-user-merge`, and refuses when the head has moved past the checks you watched before arming auto-merge; branch protection is the backstop, not the plan.
- **Preserve history**: condemned designs stay as separate commits under their fix; corrections are posted on merged PRs, not edited away.

## Step 6 — Final validation and report

When the work is merged, the validator runs the mission's closing measurement **on shipped main** against the real target from the charter — not on the branches. Then stand the team down: `scripts/stand-down.sh <scratch> <worktree>...` verifies locks free, worktrees clean, nothing unpushed (exit 0 = all clear); collect each teammate's short retro — what they'd do differently. Generate the session report from the journal (if a `session-report` skill is available, use it; otherwise write an honest HTML/MD summary to the user's Documents), including false starts and corrections — the record's value is its honesty. The report states its verified-vs-synthetic split (which behaviors real data exercised, which only fixtures did), and a reviewer — the adversarial reviewer if one exists, else the validator — gets right-of-refutation on the report itself before it ships: the coordinator is not exempt from overclaiming.

## Step 7 — Retrospective: improve this skill

This is part of the mission, not optional polish. After the report:

1. Re-read the journal end to end and each teammate's retro, hunting for: coordinator interventions that a better brief/protocol would have made unnecessary; anything discovered mid-mission that should have been known at spawn; protocol steps that earned nothing (drop candidates); new patterns that worked and generalize.
2. Append a dated entry to `LESSONS.md` in this skill's directory — see `references/retrospective.md` for the entry format and the distillation questions. Lessons must be *general* (a future mission in a different repo can apply them), not a rehash of mission specifics.
3. If a lesson contradicts or should change this SKILL.md, its references, or its scripts, propose the edit to the user with the journal evidence, and apply it on approval. The skill editing itself is the point — but the user stays in the loop on what it becomes.

## Quick reference

| Resource | When to read |
|---|---|
| `LESSONS.md` | Always, first |
| `references/mission-prompt.md` | Step 3, when writing teammate briefs |
| `references/protocols.md` | Steps 3-5: spawn commands, comms, measurement regime, PR/CI pipeline |
| `references/retrospective.md` | Step 7 |
| `scripts/spawn-teammate.sh` | Step 4 |
| `scripts/msg-teammate.sh` | Every message to a teammate, always |
| `scripts/heartbeat.sh` | Step 4, armed once as the heartbeat Monitor |
| `scripts/ci-watch.sh` | Steps 4-5, one per open PR |
| `scripts/merge-pr.sh` | Step 5, every merge — never raw `gh pr merge` |
| `scripts/log-status.sh` | Referenced in every brief; teammates call it for each status line |
| `scripts/with-heavy-lock.sh` | Referenced in every brief; wraps every heavy run |
| `scripts/stand-down.sh` | Step 6, before dismissing the team |
