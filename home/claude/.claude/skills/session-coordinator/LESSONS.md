# Lessons — accumulated mission experience

Read whole at Step 0 of every mission. **Distilled 2026-08-01**: lessons already folded into
`SKILL.md`, `references/`, or the scripts are compressed to pointer lines in the mission log at the
bottom; the full pre-distillation text is preserved in `LESSONS-archive-through-2026-07-31.md`.

**The top two sections are the live ones** — items not yet encoded anywhere. Read those properly.
The mission log below them is provenance: it tells you which mission produced a rule and where that
rule now lives, so you can find the evidence if a rule ever looks wrong.

---

## OPEN — proposed, not yet encoded

These have journal evidence behind them but no home in the skill yet. Apply, or discard with reason.

- **A work-STARTING directive must go through verified delivery; inbox-append alone strands it.** The
  inbox is polled *between steps*, and an idle or done agent has no next step. Three verdict
  directives sat unread until a heartbeat DONE plus a manual wake. Inbox-only is for context an
  *already-working* agent will pick up. → protocols.md messaging (transport vs backstop).
- **Milestone artifact handovers across live worktrees race.** Capture the artifact and its
  ground-truth dump in ONE lock hold, with `git status --short` pasted immediately before (clean at
  the milestone SHA) — and verify BINARY provenance inside the hold too (rebuild or hash-assert). A
  tree pin alone once let a stale pre-milestone binary produce a silently featureless artifact.
  → brief template measurement regime.
- **Validators should pre-publish acceptance criteria per feature BEFORE seeing the implementation.**
  It converts FAIL verdicts from taste arguments into objective checks. Corollary: put the criteria
  table in the IMPLEMENTER's brief too — polarity decided up front shapes the first implementation,
  not the fix. → validator role text + brief template.
- **Gates must be un-maskable.** A piped `clippy | tail -1` swallowed a nonzero exit and let a broken
  state commit. Ship a canonical gates recipe (pipefail + explicit FAILED/panicked grep + surfaced
  exit code) in the brief rather than letting each teammate improvise. → brief template CI-gates.
- **Ad-hoc verification snippets get none of the main rig's rehearsal.** One-off jq/regex/shell
  checks nearly produced two false findings in one mission. Every ad-hoc check gets a 10-second
  positive control before its output is believed — same rule as the rig, smaller dose.
  → validator role text. (Related and already encoded: "a fragile probe returning zero is not
  evidence of absence".)
- **Briefs must name the full runtime dependency set of every layer the validator exercises** — an
  SPA-bundle env-var hunt cost mid-verdict time. → brief template.
### Drop candidates (need a second strike before removal)

- **Graded wall-time ceilings** ("FAIL above 2s") — never came within 100x of binding across 4 phases;
  structural criteria did all the deciding. *1st strike.*
- **Standing env-var hypotheses in briefs** — refuted at design time, never relevant until the closing
  step; scope such hypotheses to the step that uses them. *1st strike.*

---

## RECORDED — true, but not template material

Situational or domain-shaped. Worth knowing; too specific to encode as a rule.

- **Validators produce impeccable measurements and fallible interpretations.** The failure mode
  recurs in new shapes every mission — most recently a *reasoning* error no self-cross-check could
  catch, because both of the validator's own signals agreed and both were wrong.
- **When a measurement violates a structural bound, distrust the measurement first** (17 "concurrent"
  processes under an 8-wide semaphore was a contamination tell).
- **Verify a diagnosis AT THE LAYER IT CLAIMS** before scoping work from it. Binding-table, injection,
  and receipt are different layers; measuring one and generalising produced a mission's only wasted
  scope addition.
- **Decisive-experiment adjudication beats theory-ruling.** Every teammate dispute across several
  missions ended with the challenged party running a specified experiment and conceding on artifacts
  — no coordinator fiat needed. Keep it as the default dispute protocol.
- **When two identities behave differently against the same API, diff the identities first** (roles,
  claims — one read call) before theorising about state (caching, staleness, restarts).
- **The teammate whose module arrives second pre-measures the join** — compile the peer's swap on your
  own branch and report "0 compile errors, N test failures, root cause X". Turns integration into one
  mechanical round.
- **Golden files are only trustworthy if regeneration is gated on a diff against the committed copy.**
  A checker once silently lost an entire attribution class (uninitialised awk var); only
  diff-before-regenerate caught it. Design expected values around the RULE, not around what currently
  passes.
- **In event-stream aggregation, hunt duplicate-event families FIRST** — the same fact reported twice
  under different names silently inflates every number, and no test catches a double-count you don't
  know exists. Dedup proof = summed totals per source identical across the twin streams.
- **Decide prose-parser failure POLARITY explicitly.** "Defensive" parsing that ignores unknown lines
  manufactures wrong-POSITIVE claims. Unknown content degrades to "not collected"; over-absence is
  the safe direction. Torture fixtures need a CONTENTION/NOISE dimension, not just mangled content.
- **Live state is part of the fixture.** A reference output can change meaning when the system catches
  up to it (a dry-run's 85/1057 became 0/0 once the store satisfied the closure). Ground truth
  carries capture-time provenance; validators regenerate rather than inherit dumps.
- **TUI smoke-testing needs a real terminal emulator** — `script(1)` cannot host crossterm apps. A
  detached `tmux -L <sock>` server inside the agent's own pane plus capture-pane assertions works
  headless and can assert exact rendered numbers.
- **Broken commit signing has a sound holding pattern:** commit unsigned locally to preserve
  one-commit-per-step, declare it loudly, re-sign the whole stack before ANY push, and prove the
  signing rebase content-identical per commit (0-byte diffs) so graded verdicts carry over SHAs.
- **Keep the WRITE regime and the SHARED-RESOURCE regime separate.** Review-only cost nothing and
  twice produced a better outcome than write access would have; the one real cost (a reviewer unable
  to run the decisive live probe) was the *resource* rule, not the write rule. Conflating them argues
  wrongly for giving the reviewer write access.
- **Coordinator concession is load-bearing apparatus, not politeness.** Several of the best findings
  across missions exist because the coordinator demanded to be attacked and then did not defend. The
  avoided failure mode has a name: coordinator fiat.
- **The report's right-of-refutation must include re-deriving copied numbers from artifacts** — not
  trusting status lines, which is how one validator's overstated count reached a report — plus a
  render-verify by whoever holds the working browser.

---

## Mission log — what each mission produced, and where it now lives

- **2026-07-25 — extractor-speedup** (flake-explorer, 2 teammates, 6 green PRs, 1.7-3.1x) — *founding
  mission.* Produced the skill itself: briefs, `msg-teammate.sh`, `heavy.lock`, the validator role,
  negative controls, arithmetic-gated perf designs. Also: label beliefs vs verified facts in briefs
  (mission-prompt preamble); wins are path-dependent, so the trade-off table shows every user-relevant
  path (brief PR section); define "cold" beside every number (measurement regime); idle-with-queued-
  input auto-submit (`heartbeat.sh`).
- **2026-07-27 — wowdps-team-build** (wowdps, 3 teammates, shipped TUI meter, 0 unparsed across 493k
  real lines) — greenfield + live external data; first herdr end-to-end run. Produced: get real input
  flowing on day zero (SKILL.md Step 2 "Real input"); HYPOTHESIS labelling, never "directive"
  (brief preamble); duplicate derivation for load-bearing formats; design posts echo the depended-on
  interface surface; stubs start EMPTY and hazards are checked on BOTH sides; the verified-vs-
  synthetic split in the report (SKILL.md Step 6).
- **2026-07-28 — multiplexer-findings-fix** (dotfiles, 2 teammates, 15/15 findings, 17/17 e2e
  controls) — produced: `CLAUDE_CONFIG_DIR` forwarding on spawn; HYPOTHESIS labelling extended to
  recipes; every rig ships a rehearsed POSITIVE control and a broken rig reports ERROR not FAIL; a
  probe must survive and not replace what it observes; heartbeat 2-read debounce; `log-status.sh`
  stamps time and HEAD SHA itself; the `--retract` banner convention.
- **2026-07-28 — keycloak-e2e** (p4c-portal, 3 teammates incl. mid-mission adversary, 5 PRs, 2
  security fixes) — produced: briefs state questions, never expected conclusions; ALL/ONLY/LAST claims
  publish only with the enumeration command and pasted output; a guard test merges only with a red run
  under the exact mutation it guards; shared-dependencies line in every brief and cross-stream
  contradictions as first-class findings; **the adversarial-reviewer role** (SKILL.md Step 3); herdr
  `--workspace` pinning on spawn; paste-don't-recall for identifiers; preflight-ASSERT environment
  invariants with named remedies; **right-of-refutation on the final report** (Step 6).
- **2026-07-28 — user feedback: integration-policy violation** — a mission opened PRs and merged to
  main against an explicit "no PRs". **Never infer permission to publish or merge from the existence
  of CI, a remote, or this skill's own pipeline; the pipeline serves the charter, not the reverse.**
  Produced the whole policy gate: Step-1 molding question, `mission-policy` file, `spawn-teammate.sh`
  refusal, `merge-pr.sh` enforcement, binding brief section.
- **2026-07-29 — graph-data-mission** (flake-explorer, 2 teammates, 6/6 milestones) — first
  `local-merge` run; first mid-mission multiplexer upgrade underfoot. Produced: briefs-as-files with a
  one-line bootstrap prompt as the CLI-agnostic delivery shape. **Several of its lessons are still
  open — see the OPEN section above.** One is now closed: **APPLIED 2026-08-01** — `stand-down.sh`
  reads the mission policy (auto-detected from `<scratch>/mission-policy`, overridable with
  `--policy <file>`) and downgrades the "not on any remote" check to `info` under `no-github` and
  `local-merge`, where unpushed is the designed state and there may be no remote at all. An absent or
  unreadable policy file stays STRICT. Self-test covers both directions on a repo with a remote AND
  on a repo with none — the latter being the shape that produced the original 3 spurious FAILs.
- **2026-07-30 — graph-ui-mission** (flake-explorer, 2 teammates, 4 stacked PRs, survived a
  mid-mission reboot) — first `prs-user-merge` run. Produced: publish next-phase criteria AT the
  current verdict via verified delivery; phase-branch creation is the FIRST action of a phase;
  milestone declarations get their own status line and headline; criteria are instruments and inherit
  every instrument rule; validators measure the data surface BEFORE publishing criteria; fixtures need
  a REACHABILITY check; the pause/resume-across-reboot procedure (protocols.md); state the stacked-PR
  convention once.
- **2026-07-31 — hcc-2440-authn** (p4c-control-plane + p4c-k8s, 4 teammates incl. adversary, 6 PRs
  merged, central claim upgraded synthetic→live) — security hardening from a pre-written plan.
  **Dominant finding: one error SHAPE accounted for 12 defects across all five sessions, including
  the plan twice and the coordinator — the scope of the verifying command was narrower than the
  domain of the claim it supported.** Produced, all now encoded: the domain/scope rule and the
  SHARED-NOUN corollary (brief template + SKILL.md Step 2 source-document audit); publication
  labelling for cheaper retraction — CONFIRMED|PLAUSIBLE + scope string + decisive experiment (brief
  template); brief the INVARIANT never the MECHANISM and the design-review question "has each
  assertion here been observed to fail?" (Step 5); handed-down facts carry their verification SCOPE;
  PROVENANCE markers on forwarded findings; calibration samples labelled HYPOTHESIS with refutation
  pre-authorised (Step 3); the head-moved rule asks for the RANGE not the commit (protocols.md);
  right-of-refutation extended to the VALIDATOR's evidence claims (Step 3); *your own artifacts are
  unreviewed by default* (Step 5); `rc=0` proves the tool ran, not that your intent landed (Step 4);
  sequence the report refutation before releasing anything you would need to re-measure (Step 6);
  intent-vs-attachment guards, false-pass generators, changed test counts, "builds but ships nothing",
  and the all-false-positives case where mutation is the only evidence (brief template); script fixes
  to `msg-teammate.sh` (refuses `--`-leading messages, probes both CLI spellings) and
  `spawn-teammate.sh` (seeds the inbox file, probes both wait flags).
