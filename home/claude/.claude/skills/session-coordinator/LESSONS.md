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

## 2026-09-18 — p4-history-in-serve (Perforce tree, no git; 4 then 5 teammates; herdr; Fable-5.1-low implementers) — DRAFT, P5 addendum pending

**Mission shape.** Plan-driven build of 5 phases over a shared Perforce client (no worktrees possible). Policy `no-github` mapped to
"nobody submits; per-agent numbered changelists; file ownership by directory". Verdicts: P1, P1b, P2, P2b, P3, P4 all MERGE-OK.

### Lessons general enough to encode
- **A precondition must be verified on the SAME process the tests use.** The runner checked the browser on the port it was told and
  the suites drove the default port; the gate certified one browser while the tests exercised another for hours. Detector: the suite
  asserts the identity (port/pid/URL) of the thing it drove, inside the suite.
- **Static "is it wired" checks do not find "delivered to no page".** A route existed, a fetch for it existed in an inline client, and
  no page ever received that client. Only a runtime drive (open the affordance, observe the effect) catches this. A grep of route
  names reported it wired. → review checklist: drive every affordance once in a browser.
- **A count-only decisive test passes a meaning-inverting bug.** Record counts came out right while a marker attached to the wrong
  record. Decisive tests assert MEANING (which record carries the field), never just cardinality.
- **Audit the output FORMAT the parser consumes.** Two rulings were wrong because the author audited plain output while the parser
  read -ztag (which carries fields plain output omits; which has no phrase the plain form has).
- **A measurement taken outside the allowlist cannot detect the allowlist.** A discriminator was costed by running p4 in a shell;
  through the code path it could never run (verb not allowed). Measure through the wrapper the code uses.
- **Contract conforms to gated code.** When a document revision lands after a phase is gated, shipped shapes that satisfy the rule ARE
  the contract; new style applies from the next phase. Prevented two retrofit churns.
- **"Present and inert" beats "absent" for dark-mode features.** An absent section is bytes in a region no mask covers; present-and-
  inert is byte-identical by construction. The same author ruled "absent" three times before this became a rule.
- **Every non-ok outcome must change something observable — in BOTH directions.** Four variants found in one afternoon: falsy return;
  flag no consumer reads; bare catch mapping our bug to "outage"; empty collection presented as silence. One grep-able rule per variant.
- **Briefs cite revisions that move.** A brief naming "REV 4" cost the implementer a wrong build when the contract was at REV 6 by
  spawn time. Briefs cite the FILE and say "read the change log first".
- **The predecessor's scratch scripts belong in the handover brief.** Each agent's reds live in its own session scratchpad; the
  checkpoint must list them by absolute path with what each proves.
- **Compaction at ~80% with (a) a fresh checkpoint, (b) a role-specific focus line, (c) the coordinator re-sending the held directive
  list afterward** held every directive across four compactions BY SELF-REPORT (5/5, 4/4, 5/5, 4/4; no independent instrument) and no directive needed re-issuing afterward. Cheaper than handover; do it first.
- **A handover to a cheaper model worked** (Opus → Fable 5.1 low for both implementers) when the brief pointed at a checkpoint and
  said "trust it over memory; re-verify, do not inherit".
- **The validator's own floors catch the coordinator.** An anti-vacuity floor (≥8 stable golden pages) rejected a coordinator ruling
  that would have dropped coverage; keep such floors and let them bind rulings.
- **Never assert a teammate's evidence for it** — done twice by the coordinator this mission (count attribution; "you verified this
  in R0-24"). Both corrected by the teammate. Cite the artifact or say "per X's report".
- **Never narrate a clock time you did not read.** Coordinator prose drifted an hour ahead of the measured stamps.

### Drop candidates
- Wall-time ceilings again never bound (2nd strike): 1.5 s blame pending, 700 ms scan — structural spawn counts decided everything.

### Numbers
- Contract revisions: P1 34, P2 5, P2b 13, P3 7, P4 16, P5 4. Review findings ~70, of which ~8 withdrawn by review itself.
- Coordinator retractions: 9 (docs-check cause; count attribution ×2; count-only test; fstat probe; "ask design" in a rule; invented
  timestamps; grep detector; golden ruling vs floor; 503 "names the feature").
- **(design retro) 29 published errors in one document lineage shared FOUR shapes; the largest (7) was an ALL-claim short a
  member; 3 were "ruled before I read the shipped code".** Rule: a total set is written as a table with its enumeration command
  beside it; a ruling on shipped code is preceded by reading the file, and says so.
- **(review retro) 11 wrong findings in two shapes; the early shape was "the claim outran the enumeration" (an absolute measured on
  one case; a positive control that proved the command emits output rather than that the search key exists; the warm half of a
  biconditional reported as the property).** Rule: an ALL/EVERY/NEVER finding publishes with the enumeration command, its scope
  string, and a positive control that finds a KNOWN MEMBER of the specific key being searched.
- **(review retro) Write the COUNTING-TRAPS page at spawn, one shared document.** Five traps hit by three agents independently: `$?`
  after a pipe; plain vs -ztag output; `2>&1 >/dev/null` order under zsh; `grep -c '^//'` matching p4's error line; a missing wrapper
  (`timeout`) whose absence reads as a zero result. → brief template: a "measurement traps for this toolchain" section, appended to
  as they are found.
- **A correction filed in a new section while the section a reader hits first keeps the old claim** — four instances in one document
  lineage in one afternoon, one of them an hour after its author wrote the rule against it. Rule: corrections REWRITE the ruling
  block in place (with a dated note) — never annotate elsewhere; a reviewer greps the OLD sentence and expects zero hits.
- **Two agreeing measurements are not a control if they share a method.** Design and review independently got 2,146 rows by the same
  `-/+/space` count and agreed to the unit; testing's 2,221 by a different method was right, and the gap was exactly the hunk-header
  count. Rule: "independently verified" requires a DIFFERENT instrument, not a different person.
- **A p4 count is a function of the CLIENT, and the client is selected by the cwd.** The same fstat from the tree root and from a
  sub-tree gave 74,848 vs 77,492 at the same instant; design's "irreproducible" stored count reproduced exactly from the other
  directory. Rule: every recorded p4 figure carries its command, its client (or cwd), and its date. (The tree's own CLAUDE.md said
  "cd decides which client p4 talks to" in its first paragraph; three agents still hit it.)
- **(dev1 retro) A handover checkpoint must carry INSTRUMENTS, not only state:** the check scripts by path, the scratch browser's
  real viewport width (every width-dependent assertion silently reads against it), the byte-identity masks as regexes (not prose),
  which shell tools are reliable in the sandbox, and the compaction trigger so a teammate can front-load its own checkpoint.
- **(dev2 retro) The one defect no suite found (a warm route re-spawning) would have been found by asserting rule (b)'s WARM half from
  a fixture table of every immutable route, plus a cache inventory beside the cache module** — not by hoping someone thinks of it.
- **(dev1 retro) Protocol steps that earned nothing for an implementer:** HOLDING lines, re-pasting unchanged `p4 opened`, duplicate
  say lines to two recipients. Post once, to the status file; the coordinator reads it.
- **(P5 addendum) State a budget in the unit the work ITERATES OVER.** The split budget was corrected twice for scope (whole change ->
  largest file) and never for unit (hunks -> rows); the largest-by-hunks block was 85% lighter than the real worst case. Design's
  Phase 5 alone produced 9 published errors against a 176-line contract (mission total 38); the last phase was its worst.
- **(P5 addendum) The refetch that a p4-spawn count could not see cost 4 ms and logged nothing on the shim** (testing measured the
  disclosure fill at 18.6/4.1/3.7 ms). A guard that counts the wrong resource passes at zero cost; count the resource the
  behaviour actually consumes (browser fetches here).
- **(report refutation) The coordinator's report named a server hostname that appeared in no p4 output field, and listed as
  unexercised a path the team had driven and captured three artefacts for.** The refutation step exists for exactly this; it
  produced 8 findings, 2 HIGH, on a 60-line draft.
- **APPLIED 2026-09-18 (p4-history-in-serve retro, user-approved):** `no-submit` policy + Perforce mode in `spawn-teammate.sh`/`merge-pr.sh`/`stand-down.sh`; "Measurement traps for this toolchain", "Contract citations" (cite the file, not the REV), same-process precondition, same-tree-state byte-identity, different-instrument independence, and rewrite-in-place corrections in `mission-prompt.md`; "Context compaction" in `protocols.md`; the drive-every-affordance and different-instrument rules in SKILL.md Step 3. The mission entry above stays as evidence.
