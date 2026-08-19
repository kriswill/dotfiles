# Measurement traps

Every one of these produced a wrong conclusion in practice before being caught.
They fail quietly: you get a plausible number or a clean diff, not an error.

## T1. Model self-report is incomplete

Asking the model to list its own system prompt headings omitted an entire section
(`# Session-specific guidance`) that a ccglass capture proved was present. Self-report
is fine for a quick "did this text arrive at all" probe. It is not evidence for
"nothing was lost". Always capture for loss analysis.

## T2. Invalid `--settings` silently falls back

`--settings ''` is not an error. Claude Code discards it and loads the full setting
sources (CLAUDE.md, skills, MCP), producing a number roughly 3x the isolated one.
An unrecognized `outputStyle` name does the same. Two runs that differ only in a
typo'd style name differed by 17k tokens for this reason, which looked like the
style was replacing the prompt when it was doing nothing of the kind.

Always include a `--settings '{}'` control run. If your "with feature" number is
close to `{}` and your "without" number is 3x larger, you measured the fallback.

## T3. ccglass `--` placement drops flags

`ccglass claude --dir X -- -p hi --settings '{...}'` captures successfully but the
trailing flags never reach the CLI. The diff comes out byte-identical and reads as
"the change had no effect".

Correct: `ccglass run --provider claude --no-open --dir X -- claude <args>`.

## T4. Inherited CLAUDE_CONFIG_DIR contaminates every run

A Claude Code session exports `CLAUDE_CONFIG_DIR`. Any test you launch from its Bash
tool inherits it. Under the profile-selector wrapper this forces the passthrough
branch, so profile resolution is never exercised and a wrapper bug is invisible.

Set it explicitly per run. When testing the wrapper itself, `unset` it first.

## T5. Blob refs are strings, not objects

ccglass stores large values as `"sha256:<hash>"` pointing at `blobs/<xx>/<sha>.json`.
A resolver looking for `{"$blob": ...}` returns the 71-char stub. Both files extract
to the same stub, diff clean, and you conclude nothing changed.

Sanity check: an extracted system prompt under ~2000 chars means extraction failed,
not that the prompt is small.

## T6. Per-tool token costs are not additive

Measuring each tool alone against a no-tool baseline overcounts badly: individual
deltas for one session's 13 tools summed to ~24.5k against a reported 14.1k, because
each delta re-counts shared scaffolding.

Use nested cumulative sets — add one tool at a time and take the difference — so each
number is a true marginal cost. Some tools (`TodoWrite`, `AskUserQuestion`,
`ToolSearch`) are unfilterable and always show 0 marginal; that is correct, not a bug.

## T7. Variadic flags swallow the next positional

`--disallowedTools`, `--tools`, `--allowedTools` are variadic. Written with a space
and placed before a positional prompt, they consume it as another value:
`claude --disallowedTools Workflow "fix the build"` launches with no prompt. Use the
`=` form. This matters whenever a wrapper injects flags ahead of user args.

## T8. `/context` numbers are estimates

`/context` reports deferred tool sections that are not actually charged — summing
its categories exceeds its own stated total. Its "System tools" figure also did not
reconcile with measured marginal costs (14.1k reported vs ~24.5k measured). Treat it
as a ranking aid. Use real `usage` totals from `--output-format json` for anything
you intend to act on.

## T9. Prompt sections are conditional on the tool set

Parts of the system prompt appear only when a given tool is enabled. `# Session-specific
guidance`, which carries the `/<skill-name>` dispatch instruction, exists only when the
Skill tool is present. Enabling Bash pulls in sandbox and git guidance well beyond its
own schema, which is why its measured marginal cost (~4.1k tokens) far exceeds the size
of its description (~600).

Consequence: an A/B where one side used `--tools ''` and the other did not will report
that section as "lost" when the config under test never touched it. This produced a
false finding in practice, and the phantom loss was then "repaired" by adding the
instruction back into a file that had not removed it.

Change exactly one variable per pair. When a loss looks significant, re-run the pair
with the tool set forced identical before reporting it.
