# Retrospective procedure (Step 7)

The mission isn't over until the skill has learned from it. Input: the coordinator journal, teammate status files, and teammate retros. Output: a dated `LESSONS.md` entry, and (with user approval) edits to this skill.

## Distillation questions

Walk the journal with these; each "yes" is a lesson candidate:

1. **Interventions**: which coordinator messages were *corrections* (not assignments)? For each: would a better brief, protocol, or script have made it unnecessary? That's the highest-value lesson class.
2. **Late knowledge**: what did the team learn mid-mission that was knowable at spawn (CI gates, code facts, tool quirks)? Move it into recon or the brief template.
3. **Dead protocol**: which mandated steps earned nothing this mission? Don't delete on one data point — mark "candidate for removal, unused in mission N" and delete after two quiet missions.
4. **Emergent patterns**: what did a teammate invent that worked (a control, a test shape, a coordination move)? Generalize it past the mission's specifics before recording.
5. **Near-misses**: what almost shipped wrong, and what apparatus caught it? Strengthen that apparatus; ask what class of error still has no apparatus.
6. **User friction**: where did the user have to intervene or express surprise? Those are skill failures even when the mission succeeded.

## LESSONS.md entry format

Append (never rewrite history — supersede with a new entry that references the old):

```markdown
## 2026-MM-DD — <mission slug> (<repo>, <n> teammates, <outcome one-liner>)

- LESSON: <general statement applicable to future missions in other repos>.
  Evidence: <one journal fact>. Action: <what changes: brief template / protocol /
  script / SKILL.md section, or "recorded only">.
- CANDIDATE-DROP: <protocol step> unused this mission (1st/2nd strike).
```

Keep entries terse — a future coordinator reads this file whole at Step 0. When the file exceeds ~150 lines, distill: fold stable lessons into SKILL.md/references (with user approval) and compress the entries they came from to one-line pointers.

## Applying changes to the skill

- Lessons that only add knowledge → append to LESSONS.md, no approval needed.
- Lessons that change behavior (SKILL.md, references, scripts) → show the user the proposed diff plus the journal evidence, apply on approval. The skill improving itself is the goal; the user staying in control of what it becomes is the constraint.
- After any script change, re-run the script's smoke test (each script supports `--self-test`).
