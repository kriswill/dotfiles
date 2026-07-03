// Shared helpers for the OKF knowledge-bundle tooling (validate/index/scaffold/viz).
// Zero-dependency by design: the YAML parser below handles only the frontmatter
// subset this tooling emits (string scalars, flow lists, block lists) so the
// bundle stays consumable without a package.json.

import { readdirSync, statSync, readFileSync, existsSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import { spawnSync } from "node:child_process";

export type FM = Record<string, string | string[]>;

export interface ConceptDoc {
  rel: string; // path relative to bundle root, e.g. "modules/nh.md"
  abs: string;
  fm: FM | null;
  fmError: string | null;
  body: string;
  raw: string;
}

export const RESERVED = new Set(["index.md", "log.md"]);

// Fields our profile requires beyond the spec's bare `type`
// (matches the reference tooling's OKFDocument.validate()).
export const PROFILE_FIELDS = ["type", "title", "description", "timestamp"];

export function repoRoot(): string {
  return resolve(import.meta.dir, "..", "..");
}

export function bundleRoot(): string {
  return join(repoRoot(), "knowledge");
}

/** All .md files under root, as sorted bundle-relative paths. */
export function walkMd(root: string): string[] {
  const out: string[] = [];
  const walk = (dir: string) => {
    for (const entry of readdirSync(dir).sort()) {
      if (entry.startsWith(".") || entry.startsWith("_")) continue;
      const abs = join(dir, entry);
      if (statSync(abs).isDirectory()) walk(abs);
      else if (entry.endsWith(".md")) out.push(abs.slice(root.length + 1));
    }
  };
  walk(root);
  return out.sort();
}

export function parseDoc(root: string, rel: string): ConceptDoc {
  const abs = join(root, rel);
  const raw = readFileSync(abs, "utf8");
  const { fm, fmError, body } = parseFrontmatter(raw);
  return { rel, abs, fm, fmError, body, raw };
}

export function parseFrontmatter(raw: string): {
  fm: FM | null;
  fmError: string | null;
  body: string;
} {
  if (!raw.startsWith("---\n")) return { fm: null, fmError: null, body: raw };
  const end = raw.indexOf("\n---\n", 4);
  if (end === -1) return { fm: null, fmError: "unterminated frontmatter block", body: raw };
  const block = raw.slice(4, end);
  const body = raw.slice(end + 5);
  const fm: FM = {};
  const lines = block.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!line.trim() || line.trim().startsWith("#")) continue;
    if (/^\s/.test(line)) return { fm: null, fmError: `unexpected indented line: ${line.trim()}`, body };
    const m = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!m) return { fm: null, fmError: `unparseable line: ${line}`, body };
    const [, key, rest] = m;
    if (rest === "") {
      // block list
      const items: string[] = [];
      while (i + 1 < lines.length && /^\s+-\s+/.test(lines[i + 1])) {
        items.push(unquote(lines[++i].replace(/^\s+-\s+/, "")));
      }
      fm[key] = items;
    } else if (rest.startsWith("[")) {
      const inner = rest.replace(/^\[/, "").replace(/\]\s*$/, "");
      fm[key] = inner.trim() === "" ? [] : inner.split(",").map((s) => unquote(s.trim()));
    } else {
      fm[key] = unquote(rest);
    }
  }
  return { fm, fmError: null, body };
}

function unquote(s: string): string {
  if ((s.startsWith("'") && s.endsWith("'")) || (s.startsWith('"') && s.endsWith('"')))
    return s.slice(1, -1).replace(/''/g, "'");
  return s;
}

function yamlScalar(s: string): string {
  if (s === "" || /[:#'\[\]{}]|^\s|\s$|^[-?&*!|>%@`"]/.test(s) || /^[\d.]+$/.test(s))
    return `'${s.replace(/'/g, "''")}'`;
  return s;
}

export function fmToYaml(fm: FM): string {
  const lines: string[] = [];
  for (const [k, v] of Object.entries(fm)) {
    if (Array.isArray(v)) lines.push(`${k}: [${v.map(yamlScalar).join(", ")}]`);
    else lines.push(`${k}: ${yamlScalar(v)}`);
  }
  return `---\n${lines.join("\n")}\n---\n`;
}

/** Markdown link targets in body order (skips images and fenced code blocks). */
export function extractLinks(body: string): string[] {
  const out: string[] = [];
  let inFence = false;
  for (const line of body.split("\n")) {
    if (/^\s*(```|~~~)/.test(line)) { inFence = !inFence; continue; }
    if (inFence) continue;
    for (const m of line.matchAll(/(?<!!)\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g)) out.push(m[1]);
  }
  return out;
}

export function isExternal(target: string): boolean {
  return /^[a-z][a-z0-9+.-]*:/.test(target) || target.startsWith("#");
}

/** Resolve a doc-relative link target to a bundle-relative path (or null if it escapes). */
export function resolveLink(root: string, docRel: string, target: string): string | null {
  const clean = target.split("#")[0];
  if (!clean) return null;
  const abs = resolve(root, dirname(docRel), clean);
  return abs.startsWith(root + "/") ? abs.slice(root.length + 1) : null;
}

export function titleFromSlug(slug: string): string {
  return slug
    .split("-")
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
}

// One batched `git log --name-only` pass (newest first) instead of a git
// subprocess per gitISO() call — the per-file spawns dominated viz/scaffold
// build time.
let gitDates: Map<string, string> | null = null;

function loadGitDates(): Map<string, string> {
  const map = new Map<string, string>();
  const r = spawnSync("git", ["-c", "core.quotepath=off", "log", "--format=%x00%cI", "--name-only"], {
    cwd: repoRoot(),
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  let date = "";
  for (const line of (r.stdout ?? "").split("\n")) {
    if (line.charCodeAt(0) === 0) date = line.slice(1); // NUL from %x00 marks a commit line
    else if (line && !map.has(line)) map.set(line, date); // first hit = newest
  }
  return map;
}

/** ISO-8601 timestamp of a path's last commit; falls back to the current time. */
export function gitISO(path: string): string {
  gitDates ??= loadGitDates();
  const exact = gitDates.get(path);
  if (exact) return exact;
  // Directories never appear in --name-only output — take the newest file
  // under the prefix (the map preserves newest-first insertion order).
  const prefix = path.endsWith("/") ? path : path + "/";
  for (const [k, d] of gitDates) if (k.startsWith(prefix)) return d;
  return nowISO();
}

export function nowISO(): string {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "+00:00");
}

export function fileExists(p: string): boolean {
  return existsSync(p);
}

// ANSI colors, gated on TTY and NO_COLOR so piped/captured output stays plain.
const tty = process.stdout.isTTY === true && !process.env.NO_COLOR;
const paint = (open: string) => (s: string) => (tty ? `\x1b[${open}m${s}\x1b[0m` : s);
export const c = {
  bold: paint("1"),
  dim: paint("2"),
  red: paint("31"),
  green: paint("32"),
  yellow: paint("33"),
  cyan: paint("36"),
};
