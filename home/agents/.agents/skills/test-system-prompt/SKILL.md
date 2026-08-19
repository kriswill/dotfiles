---
name: test-system-prompt
description: Empirically test what actually reaches the model. Captures the literal system prompt via the ccglass proxy, diffs configurations to find lost or degraded capabilities, measures token cost, and verifies that a rule actually fires. Use when changing an output style, CLAUDE.md, settings.json, hooks, or tool sets; when a rule seems to be ignored; when deciding whether guidance belongs in CLAUDE.md, a skill, or a hook; or when the user says "/test-system-prompt", "what is actually in my system prompt", "did that change take effect", "why is Claude ignoring X", "is this rule worth the tokens".
---

# Test system prompt

Determine what the model actually receives, what a config change costs, and what it
silently removes. Report findings the user can act on.

## Core principle

**Capture, do not ask.** The model's account of its own instructions is incomplete —
it has omitted an entire section that a proxy capture proved was present. Self-report
answers "did this text arrive". Only a capture answers "what went missing".

Every claim in the final report must trace to a captured byte, a measured token count,
or a behavioral probe. No inference presented as measurement.

## Setup

Required: `ccglass` on PATH (LLM traffic inspector), `bun`, `jq`.

Scripts live beside this file:

- `scripts/capture.sh <outdir> [claude-args...]` — capture a real request
- `scripts/extract-system-prompt.ts <dir> <out.txt>` — pull the literal system field
- `scripts/compare.ts <base.txt> <cand.txt>` — report what was LOST, exit 1 if any

Read `references/measurement-traps.md` before interpreting any number. Eight documented
ways this measurement silently lies. Skipping it produces confident wrong answers.

## Procedure

Run only the phases the question needs. A "did my change land" check is P1 + P2.
A full audit is P1 through P6.

### P1. Establish a baseline

Capture the current config with the candidate change absent.

```bash
SK=~/.claude-work/skills/test-system-prompt
bash $SK/scripts/capture.sh /tmp/tsp-base --tools '' --settings '{}'
bun $SK/scripts/extract-system-prompt.ts /tmp/tsp-base /tmp/tsp-base.txt
```

**Hold the tool set identical across baseline and candidate.** `--tools ''` does not
merely drop schemas, it removes tool-conditional prompt sections: `# Session-specific
guidance` exists only when the Skill tool is present. Varying tools between the two
captures manufactures phantom losses (trap T9).

If the extract is under ~2000 chars, extraction failed. Do not proceed.

### P2. Capture the candidate and diff

Apply the change, capture again, compare.

```bash
bash $SK/scripts/capture.sh /tmp/tsp-cand --settings '{"outputStyle":"NAME"}'
bun $SK/scripts/extract-system-prompt.ts /tmp/tsp-cand /tmp/tsp-cand.txt
bun $SK/scripts/compare.ts /tmp/tsp-base.txt /tmp/tsp-cand.txt
```

`compare.ts` exits non-zero when instruction lines disappeared. **Review every lost
line.** Size can grow while capability shrinks: measured against a matched baseline,
an output style added 6663 bytes and still deleted the role line
`You are an interactive agent that helps users with software engineering tasks.`

Before reporting any loss, re-run the pair with only the suspected variable changed.
A first pass on that same style appeared to delete an entire section; holding the tool
set constant showed the section was never touched.

For each lost line decide: harmless duplication, or a real capability gap. Name the
gap concretely (which skill stops dispatching, which safety rule stops applying),
never as "some guidance was removed".

Interactive-only content will not appear in a headless capture. If a section is
present in the live session's context but absent from the baseline capture, read it
from the live session and note that the capture cannot see it.

### P3. Verify the rule actually fires

Presence in the prompt is not compliance. For each rule under test, write a probe
whose correct answer is impossible without the rule, and run it both ways.

```bash
probe() { CLAUDE_CONFIG_DIR=~/.claude-work command claude -p "$2" \
  --output-format json --tools '' --settings "$1" 2>/dev/null \
  | tail -1 | jq -r '.result'; }

probe '{}'                          "Quote the line beginning 'Replicate the'."
probe '{"outputStyle":"NAME"}'      "Quote the line beginning 'Replicate the'."
```

Good probes: quote a verbatim line, expand an alias defined only by the change, or
pose a task the rule should visibly redirect. Bad probes: "do you follow rule X",
which the model will affirm either way.

### P4. Measure cost

Token totals come from real usage, not `/context`.

```bash
m() { CLAUDE_CONFIG_DIR=~/.claude-work command claude -p "say ok" \
  --output-format json --tools '' --settings "$1" 2>/dev/null \
  | tail -1 | jq -r '.usage | (.input_tokens + (.cache_creation_input_tokens//0) + (.cache_read_input_tokens//0))'; }
m '{}'                        # control — REQUIRED, see trap T2
m '{"outputStyle":"NAME"}'
```

Sanity check the delta against file size. Roughly 3 bytes per token means pure
addition. A delta far from that means the harness restructured the prompt; find out
how before reporting the number.

For per-tool cost, use nested cumulative sets so each figure is a true marginal:

```bash
SET=""; PREV=$(m '{}')
for t in Read Edit Write Bash Skill Agent Workflow; do
  SET="${SET:+$SET,}$t"
  N=$(command claude -p "say ok" --output-format json --tools "$SET" 2>/dev/null \
      | tail -1 | jq -r '.usage | (.input_tokens + (.cache_creation_input_tokens//0) + (.cache_read_input_tokens//0))')
  printf '%-12s marginal=%s\n' "$t" "$((N-PREV))"; PREV=$N
done
```

### P5. Place the rule correctly

Cost and reliability both depend on placement. Recommend by what the rule needs:

| Need | Put it in | Why |
| --- | --- | --- |
| Must always happen, deterministically | hook in `settings.json` | the harness executes it; prompt text is only weighed |
| Applies to every project | `~/.claude-work/CLAUDE.md` | always loaded, always costs |
| Applies to one repo | that repo's `CLAUDE.md` | lazy-loaded when a file there is touched, free until relevant |
| Applies to one task type | a skill | only the description is resident |
| Shapes tone and response form globally | output style | additive, but audit P2 losses first |
| Machine-local, uncommitted | `.claude/settings.local.json` | not shared |

`settings.json` has real precedence: managed > CLI flags > `.claude/settings.local.json`
> `.claude/settings.json` > `~/.claude-work/settings.json`.

CLAUDE.md files have none. They are concatenated as equal-weight text; conflicts are
resolved by the model weighing specificity and recency. If a project rule must beat a
global one, say so explicitly in the project file. Never report CLAUDE.md layering as
if it were enforced precedence.

### P6. Recommend refinements

Report only changes justified by P2 through P5 evidence. Typical outcomes:

- Restore a lost instruction by adding it to the file that displaced it.
- Move a rarely-used always-loaded block into a skill.
- Convert a "always do X" instruction that measurably does not fire into a hook.
- Drop a rule that duplicates something already in the default prompt.
- Fix self-references that no longer resolve (a heading renamed out from under a
  pointer to it).

## Reporting

Assign reference codes and keep them stable for the rest of the conversation:
`F1..` findings, `R1..` risks, `O1..` options, `A1..` actions, `Q1..` questions.

State for each finding: what was measured, the number or captured line, and the
consequence. Lead with losses and gaps, not with what was added.

Close with the single remaining delta if one exists. Do not claim a config is clean
until `compare.ts` exits zero or every lost line has been explicitly accepted.

## Scope

Analysis and measurement. Do not edit CLAUDE.md, settings, or styles unless asked —
report the evidence and the recommended change. When asked to apply a fix, re-run P2
and P3 afterward and show the new numbers.
