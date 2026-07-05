// The stable API handed to repo-owned scaffolder scripts. okf dynamically
// imports the configured `[scaffold] script` and calls its default export
// with a ScaffoldContext — dependency injection, so the script needs NO
// runtime import from the okf checkout (which may be vendored, cloned
// anywhere, or a /nix/store path). Scripts may use a type-only import of
// this module for editor support (bun erases type imports) plus node/bun
// builtins; they must not depend on their own node_modules.

import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { PLACEHOLDER_RE, type OkfConfig, type OkfContext } from "./config-cli";
import { fmToYaml, nowISO, parseFrontmatter, titleFromSlug, type FM } from "./lib";
import type { VcsProvider } from "./vcs";

export type { FM };

export interface ScaffoldContext {
  /** Absolute workspace root. */
  root: string;
  /** Absolute bundle root. */
  bundle: string;
  /** Workspace-relative bundle dir (cfg.viz.bundle.dir). */
  bundleDir: string;
  config: OkfConfig;
  vcs: VcsProvider;
  /** --force was passed: existing docs are overwritten. */
  force: boolean;

  /** Write a concept doc at a bundle-relative path. The idempotence
   *  contract lives here: existing files are skipped unless `force`;
   *  directories are created; frontmatter is serialized and the body
   *  trimmed; `+ rel` is logged and the shared written/skipped summary
   *  fed. Returns true if written. */
  emit(rel: string, fm: FM, body: string): boolean;

  /** ISO-8601 last-modified of a workspace-relative path (VCS-backed,
   *  falling back to the current time — the old gitISO contract). */
  timestamp(path: string): string;

  /** Leading comment block at the top of a source file, joined to one
   *  string. `marker` is a line prefix ("#", "--", "//") or a RegExp whose
   *  group 1 captures the comment text. Null: no leading comment. */
  leadingComment(src: string, marker: string | RegExp): string | null;

  firstMatch(src: string, re: RegExp): string | null;
  /** Collapse whitespace runs and trim. */
  clean(s: string): string;
  /** clean() + ensure terminal punctuation. */
  sentence(s: string): string;
  /** First sentence of a blurb, for frontmatter descriptions. */
  firstSentence(s: string): string;
  /** Wrap bare URLs in angle brackets (MD034) for markdown bodies. */
  mdSafe(s: string): string;
  titleFromSlug(slug: string): string;
  fmToYaml(fm: FM): string;
  parseFrontmatter(raw: string): ReturnType<typeof parseFrontmatter>;
  nowISO(): string;
  log(msg: string): void;

  /** Shared written/skipped counters (the driver prints the summary). */
  counts: { written: number; skipped: number };
}

const clean = (s: string) => s.replace(/\s+/g, " ").trim();

const sentence = (s: string): string => {
  const t = clean(s);
  return /[.!?]$/.test(t) ? t : t + ".";
};

const firstSentence = (s: string): string => {
  const t = clean(s);
  const m = t.match(/^.*?[.!?](?=\s|$)/);
  return m ? m[0] : sentence(t);
};

const mdSafe = (s: string) => s.replace(/(^|[\s(])(https?:\/\/[^\s)>]+)/g, "$1<$2>");

const firstMatch = (src: string, re: RegExp): string | null => {
  const m = src.match(re);
  return m ? m[1]! : null;
};

function leadingComment(src: string, marker: string | RegExp): string | null {
  const re =
    typeof marker === "string"
      ? new RegExp(`^${marker.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s?(.*)$`)
      : marker;
  const lines: string[] = [];
  for (const line of src.split("\n")) {
    const m = line.match(re);
    if (m) lines.push(m[1]!);
    else if (line.trim() === "") continue;
    else break;
  }
  const text = lines.join(" ").trim();
  return text || null;
}

export function createScaffoldContext(ctx: OkfContext, force: boolean): ScaffoldContext {
  const counts = { written: 0, skipped: 0 };
  return {
    root: ctx.root,
    bundle: ctx.bundle,
    bundleDir: ctx.cfg.viz.bundle.dir,
    config: ctx.cfg,
    vcs: ctx.vcs,
    force,
    counts,

    emit(rel: string, fm: FM, body: string): boolean {
      const abs = join(ctx.bundle, rel);
      if (existsSync(abs) && !force) {
        counts.skipped++;
        return false;
      }
      mkdirSync(join(abs, ".."), { recursive: true });
      writeFileSync(abs, fmToYaml(fm) + "\n" + body.trim() + "\n");
      counts.written++;
      console.log(`  + ${rel}`);
      return true;
    },

    timestamp: (path: string) => ctx.vcs.lastModified(path) ?? nowISO(),
    leadingComment,
    firstMatch,
    clean,
    sentence,
    firstSentence,
    mdSafe,
    titleFromSlug,
    fmToYaml,
    parseFrontmatter,
    nowISO,
    log: (msg: string) => console.log(msg),
  };
}

/** Expand collect-entry template placeholders. Unknown placeholders were
 *  rejected at config load (same PLACEHOLDER_RE grammar — validation and
 *  expansion can't drift); expansion is a plain replace. */
export function expandTemplate(tpl: string, env: Record<string, string>): string {
  return tpl.replace(PLACEHOLDER_RE, (m, k: string) => env[k] ?? m);
}
