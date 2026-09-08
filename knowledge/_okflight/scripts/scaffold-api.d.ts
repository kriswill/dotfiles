// Vendored type surface of okf's ScaffoldContext (scaffold-api.ts in
// github:kriswill/okflight). The real implementation is INJECTED at runtime —
// `okf scaffold` dynamically imports main.ts and calls its default export
// with a live context, so scaffold passes need no runtime import from an
// okflight checkout; this file exists purely for editor/type support (bun
// erases type-only imports). Refresh it against okflight's scaffold-api.ts
// when okf's API changes; members passes rarely need are typed loosely on
// purpose — widen them here if a pass starts needing one.

/** Frontmatter map handed to emit()/fmToYaml(). */
export type FM = Record<string, unknown>;

/** The VCS surface scaffold passes typically need — okf's full VcsProvider
 *  (vcs/types.ts) is what's actually injected. */
export interface ScaffoldVcs {
  /** All tracked file paths, root-relative, sorted. */
  trackedFiles(): string[];
  /** ISO-8601 last-modified of a root-relative path, or null (prefer
   *  ctx.timestamp, which adds the now-fallback). */
  lastModified(path: string): string | null;
}

export interface ScaffoldContext {
  /** Absolute workspace root. */
  root: string;
  /** Absolute bundle root. */
  bundle: string;
  /** Workspace-relative bundle dir. */
  bundleDir: string;
  /** Full okflight.toml config — opaque here; see okflight's config-cli.ts. */
  config: unknown;
  vcs: ScaffoldVcs;
  /** --force was passed: existing docs are overwritten. */
  force: boolean;
  /** The `generated.by` actor for docs this pass writes (OKF §7):
   *  `[scaffold] actor` from okflight.toml, else `okflight/<version>`. */
  actor: string;

  /** Write a concept doc at a bundle-relative path (skip-if-exists unless
   *  force; dirs created; frontmatter serialized; body trimmed). Returns
   *  true if written. */
  emit(rel: string, fm: FM, body: string): boolean;

  /** ISO-8601 last-modified of a workspace-relative path (VCS-backed,
   *  falling back to the current time). Feed it to `generated.at`. */
  timestamp(path: string): string;

  /** `generated: { by: ctx.actor, at: ctx.timestamp(path) }` — the OKF v0.2
   *  trust stamp (§5.2) for a doc derived from a workspace path. */
  generated(path: string): { by: string; at: string };

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
  parseFrontmatter(raw: string): {
    fm: FM | null;
    fmError: string | null;
    body: string;
  };
  nowISO(): string;
  log(msg: string): void;

  /** Shared written/skipped counters (the driver prints the summary). */
  counts: { written: number; skipped: number };
}
