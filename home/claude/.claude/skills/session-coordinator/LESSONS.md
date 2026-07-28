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
  Action: msg-teammate.sh's bare-Enter mode is the manual tool; a watchdog loop is a candidate improvement for the next mission (try: heartbeat additionally greps for a non-empty input line and auto-submits).
- LESSON: Fresh flakes' nix eval caches confound first-ever timings by ~5x; "cold" must be defined (cold data dir vs cold machine) beside every number.
  Action: encoded in brief measurement regime.
