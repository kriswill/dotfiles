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
  Evidence: impl read idle 60s after a verified-delivery review directive, pane showed an active turn. Action: recorded; heartbeat classification note.
- LESSON: Teammate self-stamped HH:MM in status lines drifts badly (impl's stamps ran ~2h behind wall clock); the stream's arrival order is the truth, not the stamps.
  Evidence: "15:25 DONE" arrived after "17:50" validator entries. Action: candidate brief tweak — status lines use `date +%H:%M` command substitution, not the model's sense of time.
- LESSON: Validators need an explicit RETRACTION convention — a withdrawn claim must be as loud as the claim, and both self-caught retractions this mission had to invent their format.
  Evidence: e2e retro #3; two retractions (t01/t12 unsound, t16 root cause). Action: add to brief status protocol: "retract with *** RETRACTION *** + what's unsound + what survives".
