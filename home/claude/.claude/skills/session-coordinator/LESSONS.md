# Lessons — accumulated mission experience

Read whole at Step 0 of every mission. Newest entries last. Entries are appended by the Step-7 retrospective; behavior-changing lessons get folded into SKILL.md/references with user approval and compressed here to pointers.

## 2026-07-25 — extractor-speedup (kriswill/flake-explorer, 2 teammates, 6 green PRs, 1.7-3.1x) — founding mission

The mission this skill was distilled from; most of its lessons ARE the skill (briefs, msg-teammate.sh, heavy.lock, validator role, negative controls, arithmetic-gated designs, auto-merge). Recorded here beyond what the skill already encodes:

- LESSON: A wrong fact in a brief costs the teammate's first work block; label beliefs vs verified facts, and verify anything cheap to verify (one guessed "the crate is sync" was wrong; one assignment referenced an env var that existed only on an unmerged branch).
  Action: encoded in mission-prompt.md preamble; re-check assignments against *main*, not against a teammate's branch you happen to remember.
- LESSON: Validators produce impeccable measurements and fallible interpretations — the duplication blocker's measurement was exact while its root-cause theory would have lost data. Adjudicate by artifact citation, give the code's author right of reply, and be ready to withdraw your own directives fast.
  Action: encoded in SKILL.md Step 5; kept here because the failure mode recurs in new shapes.
- LESSON: Structural bounds beat samplers for detecting broken attribution (17 "concurrent" processes under an 8-wide semaphore was the contamination tell).
  Action: encoded in protocols.md; generalize: when a measurement violates an invariant, distrust the measurement first.
- LESSON: Wins are path-dependent — the same change measured 17% (isolated path) and 2.8% (saturated path) with opposite memory signs. Require the trade-off table to show every user-relevant path before any headline number is quoted.
  Action: encoded in brief template (PR section).
- LESSON: Teammate sessions strand queued self-prompts in their input box when their turn ends; an idle-with-queued-input watchdog would have saved ~6 manual interventions.
  Action: APPLIED 2026-07-28 — scripts/heartbeat.sh watches for idle-with-queued-input (2-read debounce) and auto-submits via msg-teammate.sh's verified bare-Enter; msg-teammate.sh's bare-Enter mode remains the manual tool.
- LESSON: Fresh flakes' nix eval caches confound first-ever timings by ~5x; "cold" must be defined (cold data dir vs cold machine) beside every number.
  Action: encoded in brief measurement regime.

## 2026-07-28 — multiplexer-findings-fix (kriswill/dotfiles, 2 teammates, 15/15 findings fixed, 17/17 e2e controls, GREEN merge)

- LESSON: `herdr agent start` spawns from the SERVER's env, not the caller's — a coordinator with a custom CLAUDE_CONFIG_DIR strands teammates on an OAuth login screen.
  Evidence: first spawn landed on a login prompt; --env forward fixed it. Action: spawn-teammate.sh patched mid-mission (forward CLAUDE_CONFIG_DIR via --env); pending user approval to keep, since the script is repo-stowed.
- LESSON: Mark every brief recipe as HYPOTHESIS unless verified — both validator rigs lost time to brief "facts" that were wrong (the tier-a socket knob names, "server spawns commands without pane env vars").
  Evidence: e2e retro #1; the HERDR_SOCKET_PATH knob is honored by the client, not the server. Action: add a "recipes are hypotheses — verify before relying" line to the brief template's role sections.
- LESSON: Mandate a POSITIVE self-check per rig from the start, not just negative controls: "a test that FAILS on both arms may also prove nothing" — a mis-wired rig is indistinguishable from the defect it hunts.
  Evidence: t01 false-FAIL and a t12 re-run 0/3 both traced to a stacked nested client consuming the chords; the negative-control-only protocol accepted them until the self-check rule was invented mid-mission. Action: brief template measurement regime gains "every rig ships a rehearsed positive control; rig-broken returns ERROR, never FAIL".
- LESSON: A probe must SURVIVE and NOT REPLACE what it measures. Two shapes this mission: an instrumented binding that replaced the forward action under test, and a delivery probe killed by the very byte it observed (0x1C = tty SIGQUIT kills any non-raw-mode observer, mimicking "chord swallowed").
  Evidence: t16 mis-diagnosis chain; impl's cat -v probe died to SIGQUIT. Action: recorded; fold into brief discipline as "state what your probe changes about the system; prove the artifact-under-test actually loaded/ran (assert its path/pid inside the probe)".
- LESSON: Verify a diagnosis AT THE LAYER IT CLAIMS before scoping work from it — binding-table, injection, and receipt are different layers; measuring one and generalising caused the only wasted scope addition (a "fix" that was really inert-config cleanup).
  Evidence: impl's list-keys + raw-pty artifacts vs e2e's receipt-layer observation; the version-pair binds were inert, nothing was ever swallowed. Action: recorded; adjudication rule stays "specify the decisive experiment at the disputed layer" — it resolved both disputes this mission in <30 min each.
- LESSON: Decisive-experiment adjudication beats theory-ruling: both teammate disputes (env-id vs --current race; tmux over-escape) ended with the challenged party running a specified experiment and conceding on artifacts, no coordinator fiat needed.
  Evidence: t12 rapid-fire experiment (ids [p4 p4 p4] both variants); t16 uninstrumented re-run. Action: recorded — keep as the default dispute protocol.
- LESSON: Heartbeat "idle" races turn boundaries — a teammate can read idle in the gap after a delivered message before its turn starts; check the pane before treating it as a stall.
  Evidence: impl read idle 60s after a verified-delivery review directive, pane showed an active turn. Action: APPLIED 2026-07-28 — scripts/heartbeat.sh debounces every non-working state to 2 consecutive reads.
- LESSON: Teammate self-stamped HH:MM in status lines drifts badly (impl's stamps ran ~2h behind wall clock); the stream's arrival order is the truth, not the stamps.
  Evidence: "15:25 DONE" arrived after "17:50" validator entries. Action: APPLIED 2026-07-28 — scripts/log-status.sh stamps time and HEAD SHA itself; the brief template mandates it for every status line.
- LESSON: Validators need an explicit RETRACTION convention — a withdrawn claim must be as loud as the claim, and both self-caught retractions this mission had to invent their format.
  Evidence: e2e retro #3; two retractions (t01/t12 unsound, t16 root cause). Action: APPLIED 2026-07-28 — log-status.sh --retract emits the *** RETRACTION *** banner; brief template's status protocol names it.

## 2026-07-28 — keycloak-e2e-mission (PerforceCTO/p4c-portal, 3 teammates incl. mid-mission adversary, 5 PRs merged, e2e 9/1F->32/32, 2 security fixes shipped)

- LESSON: Never let a brief's "default stance" name the expected conclusion ("update tests to match the new code"). The failing test WAS the vulnerability firing; a teammate taking the cheap path would have agreed with the brief. Briefs state questions and required investigations, not expected answers — the mandatory hazard-investigation clause is what saved this one.
  Evidence: impl retro 2/3; null===null gate, rows 7/9. Action: mission-prompt.md edit (proposed to user).
- LESSON: Claims of the form ALL/ONLY/LAST (audit completeness) are a distinct assertion class: require the enumeration command + pasted output before publishing. Both of impl's misses were this shape; both were adversary-caught and cheap to check.
  Evidence: "4 call sites/1 write" was 5/2; "tests verified load-bearing" was vacuous. Action: mission-prompt.md edit (proposed).
- LESSON: A guard test merges only with a red-run under the exact mutation it guards. Three vacuous-guard cases in one mission (dead conjunct 59/0; console-only capture green with full PII leak 28/0; static-call evasion) — all read as correct, all fell only to mutation.
  Evidence: A-1, R-4, R-6. Action: mission-prompt.md engineering discipline edit (proposed).
- LESSON: Declare the dependencies SHARED between teammate streams in every brief, and instruct reviewers to treat cross-stream assumption contradictions as a first-class finding class — the seam held the mission's biggest findings (impl assumed non-null session org normal while e2e was proving the mapper absent).
  Evidence: A-8; R-1's severity came from env-x-design cross-reference; adversary retro 1-2/3. Action: mission-prompt.md edit (proposed).
- LESSON: A dedicated adversarial-reviewer teammate (review-only, no git-write authority, mutation-mandated verdicts, MERGE-OK gate per PR) is worth its cost on security-adjacent missions.
  Evidence: 19 findings; every vacuous guard and the policy fork (A-2) came from it, none from CI or authors. Action: SKILL.md Step 3 optional role (proposed).
- LESSON: herdr `tab create` lands tabs in the currently-FOCUSED workspace, and herdr has no tab-move — spawn MUST pass --workspace <coordinator's workspace, from HERDR_PANE_ID> or teammates scatter.
  Evidence: impl/e2e landed in wE (coordinator in wD); user requested a move that proved impossible; adversary later landed in wD purely by focus timing. Action: APPLIED 2026-07-28 (user-directed) — spawn-teammate.sh pins herdr tabs via --workspace "${HERDR_PANE_ID%%:*}" and tmux windows via -t "<session_id from TMUX_PANE>:", addressing the new window by window_id thereafter; protocols.md Spawning updated.
- LESSON: In herdr, identify agents by tab `label` via `herdr tab list` (agent list rows carry no teammate name), and debounce heartbeat idle/done alerts to 2+ consecutive reads — every single-read alert this mission was a turn-boundary race; also expect a third status "done" besides working/idle.
  Evidence: heartbeat v1 false-MISSING on a nonexistent JSON field; ~6 false idle/done alerts before v4 debounce. Action: APPLIED 2026-07-28 — scripts/heartbeat.sh reads `herdr agent get <name>`'s agent_status (verified field), treats any non-working value as idle-class and reports it verbatim, and debounces to 2 reads; protocols.md updated.
- LESSON: Identifiers (SHAs, IDs) in status lines and PR bodies must be pasted from command output, never recalled — same rule class as timestamps-from-date.
  Evidence: impl cited commit 1c7be3f, an object that does not exist; real head 2e3503f. Action: APPLIED 2026-07-28 — log-status.sh stamps the HEAD SHA; brief template's status protocol extends the paste-don't-recall rule to PR bodies.
- LESSON: When two identities behave differently against the same API, diff the identities first (roles, claims — one read call) before theorizing about state (caching, staleness, restarts).
  Evidence: e2e spent ~25 min on a stale-token theory; impl's one role-mapping call settled it. Action: recorded.
- LESSON: Coordinator directives asserting code facts must name the branch they are true of — a gate merged into a feature branch is not on main. The brief-fact verification rule extends to every mid-mission directive.
  Evidence: coordinator directed an org_match assertion unreachable on main; e2e refused the vacuous test and built a tripwire instead. Action: recorded (extend brief-fact rule wording when editing).
- LESSON: Environment state that specs depend on (IdP realm config, claim mappers) needs a preflight ASSERTION with a named remedy, not just service-up checks — hand-applied config drift masquerades as deep test failures two layers away.
  Evidence: Keycloak Phase-Two config lost on container recreate; invite 404; realm-export source also lacked it. Action: recorded; validator briefs should demand "assert the env invariants your specs assume".
- LESSON: Give the reviewer right-of-refutation on the FINAL REPORT itself — the coordinator is not exempt from overclaiming. This mission's report said "leak-proof harness"; the reviewer refuted the word with a mutation on the merged code (static Logger.* evasion) plus 4 more corrections, all applied before ship.
  Evidence: adversary REPORT-OK-with-5-corrections, 18:15. Action: recorded; fold into SKILL.md Step 6 wording when next edited.

## 2026-07-28 — user feedback: integration-policy violation (post-mission)

- LESSON: The user's constraints on GitHub itself (PRs, pushing, merging) are charter-level and binding — a mission opened PRs AND merged to main despite an explicit "no PRs" instruction. Where the user gates merges on adversarial review from a separate session, an unauthorized merge destroys exactly the checkpoint the process exists for. Never infer permission to publish or merge from the existence of CI, a remote, or the skill's own pipeline; the pipeline serves the charter, not the reverse.
  Evidence: user report 2026-07-28 on the prior mission. Action: APPLIED 2026-07-28 — integration policy (no-github|push-only|prs-user-merge|prs-auto-merge) is a mandatory Step-1 molding question recorded in <scratch>/mission-policy (ask if unstated; assume push-only if the user cannot be asked); spawn-teammate.sh refuses briefs that don't declare it; merge-pr.sh refuses without --policy, refuses no-github/push-only outright, and requires per-PR --user-approved under prs-user-merge; brief template gained a binding Integration-policy section telling teammates to flag, not follow, directives that exceed the level.
