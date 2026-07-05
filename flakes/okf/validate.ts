// Validate the bundle against OKF v0.1 conformance (SPEC.md §9) plus the
// workspace's profile policy (okf.toml [profile]; defaults in config-cli.ts):
//   errors   — frontmatter must parse; `type` must be non-empty; reserved
//              filenames must not carry concept frontmatter; links must be
//              file-relative (no /-rooted paths — they break GitHub rendering)
//   warnings — missing title/description/timestamp, non-ISO timestamp,
//              dangling links (spec says tolerate; we still want to know)
// Exit 1 on errors; --strict promotes warnings to errors.

import { existsSync } from "node:fs";
import { join } from "node:path";
import { loadContext } from "./config-cli";
import { c, extractLinks, isExternal, parseDoc, resolveLink, walkMd } from "./lib";

const STRICT = process.argv.includes("--strict");
const { root: repo, bundle, cfg } = loadContext();
const { requiredFields, rootedLinks, repoLinks } = cfg.profile;
const reserved = new Set(cfg.profile.reservedFiles);
// A field listed in both never double-reports — required wins.
const recommendedFields = cfg.profile.recommendedFields.filter((f) => !requiredFields.includes(f));

const errors: string[] = [];
const warnings: string[] = [];

if (!existsSync(bundle)) {
  console.error(`no bundle at ${bundle}`);
  process.exit(1);
}

const files = walkMd(bundle);
for (const rel of files) {
  const doc = parseDoc(bundle, rel);
  const base = rel.split("/").pop()!;
  const isRootIndex = rel === "index.md";

  if (reserved.has(base)) {
    // index.md may carry frontmatter only at the bundle root (okf_version etc.)
    if (doc.fm && !isRootIndex) errors.push(`${rel}: reserved file must not have frontmatter`);
    if (isRootIndex && doc.fm && !doc.fm.okf_version)
      warnings.push(`${rel}: root index frontmatter should declare okf_version`);
  } else {
    if (doc.fmError) errors.push(`${rel}: frontmatter error — ${doc.fmError}`);
    else if (!doc.fm) errors.push(`${rel}: missing frontmatter (every concept needs at least 'type')`);
    else {
      // "Empty" must cover both frontmatter value shapes: "" and [] (an
      // empty array is truthy, so a bare falsy check silently passes it).
      const empty = (v: unknown) => !v || v === "" || (Array.isArray(v) && !v.length);
      for (const f of requiredFields)
        if (empty(doc.fm[f])) errors.push(`${rel}: empty or missing '${f}'`);
      for (const f of recommendedFields)
        if (!doc.fm[f]) warnings.push(`${rel}: missing recommended field '${f}'`);
      const ts = doc.fm.timestamp;
      if (typeof ts === "string" && ts && Number.isNaN(Date.parse(ts)))
        warnings.push(`${rel}: timestamp '${ts}' is not ISO-8601 parseable`);
    }
  }

  for (const target of extractLinks(doc.body)) {
    if (isExternal(target)) continue;
    if (target.startsWith("/")) {
      if (rootedLinks === "error")
        errors.push(`${rel}: /-rooted link '${target}' — profile requires file-relative links`);
      continue; // site-rooted targets can't be resolved against the tree either way
    }
    const inBundle = resolveLink(bundle, rel, target);
    if (inBundle !== null) {
      if (!existsSync(join(bundle, inBundle)))
        warnings.push(`${rel}: dangling bundle link '${target}'`);
    } else if (repoLinks === "forbid") {
      errors.push(`${rel}: link '${target}' leaves the bundle — profile forbids repo links`);
    } else if (repoLinks === "check") {
      // Escapes the bundle — allowed (points into the repo), but verify it resolves.
      const inRepo = resolveLink(repo, join(cfg.viz.bundle.dir, rel), target);
      if (inRepo === null) errors.push(`${rel}: link '${target}' escapes the repository`);
      else if (!existsSync(join(repo, inRepo)))
        warnings.push(`${rel}: dangling repo link '${target}'`);
    }
  }
}

for (const w of warnings) console.log(`${c.yellow("warn:")}  ${w}`);
for (const e of errors) console.log(`${c.red("ERROR:")} ${e}`);
const summary = `${files.length} files checked — ${errors.length} error(s), ${warnings.length} warning(s)`;
console.log("\n" + (errors.length ? c.red(summary) : warnings.length ? c.yellow(summary) : c.green(summary)));
process.exit(errors.length || (STRICT && warnings.length) ? 1 : 0);
