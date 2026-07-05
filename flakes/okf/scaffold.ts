// Generic scaffold driver. The repo owns its metadata pass: okf.toml's
// [scaffold] configures a script (dynamically imported; default export gets
// the ScaffoldContext), or a command (non-JS escape hatch, spawned with
// OKF_* env), plus 0..n declarative [[scaffold.collect]] entries (glob +
// templates) run after the imperative tier so it wins output collisions —
// emit skips existing paths. Idempotent: existing docs are never touched
// without --force.

import { readFileSync } from "node:fs";
import { basename, dirname, extname, join } from "node:path";
import { loadContext } from "./config-cli";
import type { CollectEntry } from "./config-cli";
import { createScaffoldContext, expandTemplate, type ScaffoldContext } from "./scaffold-api";

const FORCE = process.argv.includes("--force");
const ctx = loadContext();
const sctx = createScaffoldContext(ctx, FORCE);
const { script, command, collect } = ctx.cfg.scaffold;

if (!script && !command && !collect.length) {
  console.log(
    "scaffold: nothing configured — add a [scaffold] section to okf.toml (script, command, or [[scaffold.collect]] entries)",
  );
  process.exit(0);
}

if (script) {
  const abs = join(ctx.root, script);
  let run: unknown;
  try {
    run = (await import(Bun.pathToFileURL(abs).href)).default;
  } catch (e) {
    console.error(`scaffold: cannot load ${script} — ${e instanceof Error ? e.message : e}`);
    process.exit(1);
  }
  if (typeof run !== "function") {
    console.error(`scaffold: ${script} must default-export a function (ctx: ScaffoldContext) => void`);
    process.exit(1);
  }
  await (run as (c: ScaffoldContext) => unknown)(sctx);
}

if (command) {
  const r = Bun.spawnSync({
    cmd: command,
    cwd: ctx.root,
    stdout: "inherit",
    stderr: "inherit",
    env: {
      ...process.env,
      OKF_ROOT: ctx.root,
      OKF_BUNDLE: ctx.bundle,
      OKF_BUNDLE_DIR: ctx.cfg.viz.bundle.dir,
      OKF_FORCE: FORCE ? "1" : "0",
    },
  });
  if (r.exitCode !== 0) {
    console.error(`scaffold: command failed (exit ${r.exitCode}): ${command.join(" ")}`);
    process.exit(1);
  }
}

// --- Declarative collect tier -------------------------------------------------
function runCollect(entry: CollectEntry) {
  const glob = new Bun.Glob(entry.glob);
  const emitted = new Set<string>();
  for (const path of ctx.vcs.trackedFiles()) {
    if (!glob.match(path)) continue;
    const name = basename(path, extname(path));
    const dir = dirname(path);
    const env: Record<string, string> = {
      path,
      name,
      Title: sctx.titleFromSlug(name),
      dir,
      timestamp: sctx.timestamp(path),
      repo: "", // filled once the output path (and thus the doc's depth) is known
    };
    const out = expandTemplate(entry.output, env);
    // The ../.. chain from the output doc's directory to the workspace root,
    // for authoring profile-legal file-relative links in template bodies.
    const depth = join(ctx.cfg.viz.bundle.dir, out).split("/").length - 1;
    env.repo = Array(depth).fill("..").join("/");
    const commentText = entry.comment
      ? sctx.leadingComment(readFileSync(join(ctx.root, path), "utf8"), entry.comment)
      : null;
    const rawDesc =
      commentText ?? (entry.description ? expandTemplate(entry.description, env) : env.Title);
    env.description = sctx.firstSentence(rawDesc);
    env["description-sentence"] = sctx.mdSafe(sctx.sentence(rawDesc));
    if (emitted.has(out)) {
      console.log(`  ! ${path}: output ${out} already emitted this run — skipped`);
      continue;
    }
    emitted.add(out);
    const fm: Record<string, string | string[]> = {
      type: entry.type,
      title: entry.title ? expandTemplate(entry.title, env) : env.Title,
      description: env.description,
      resource: path,
      ...(entry.tags.length ? { tags: entry.tags } : {}),
      timestamp: env.timestamp,
    };
    for (const [k, v] of Object.entries(entry.frontmatter)) fm[k] = expandTemplate(v, env);
    const body = entry.body
      ? expandTemplate(entry.body, env)
      : `${env["description-sentence"]}\n\n## Source\n\n- Source: [\`${path}\`](${env.repo}/${path})`;
    sctx.emit(out, fm, body);
  }
}

for (const entry of collect) runCollect(entry);

console.log(
  `\nscaffold: ${sctx.counts.written} written, ${sctx.counts.skipped} skipped (existing)${FORCE ? " [--force]" : ""}`,
);
