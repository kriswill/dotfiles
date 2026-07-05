// The version-control abstraction every okf command builds on. Providers
// supply workspace facts (tracked files, per-path modification times,
// revision-citation resolution, remote URL); commands never spawn a VCS
// binary directly. Shipping providers: git (vcs/git.ts) — "none" (plain
// filesystem) lands with the root-discovery rework; future systems
// (Perforce, …) implement this same surface.

export interface VcsProvider {
  /** Provider id, as configured via okf.toml `[vcs] provider`. */
  readonly name: string;
  /** Absolute workspace root. */
  readonly root: string;

  /** All tracked file paths, root-relative, sorted. One batch call. */
  trackedFiles(): string[];

  /** ISO-8601 last-modified timestamp of a root-relative path. Directory
   *  arguments resolve to the newest entry under the prefix. Null: unknown
   *  (callers pick their own fallback, typically nowISO()). */
  lastModified(path: string): string | null;

  /** Map candidate revision citations (possibly abbreviated) to canonical
   *  full ids in one batch; candidates that don't resolve in this workspace
   *  (doc examples, other repos' revs, ambiguous prefixes) are dropped. */
  resolveRevisions(candidates: string[]): Record<string, string>;

  /** Pattern whose capture group 1 is an inline revision citation in doc
   *  prose (git: backticked 7-40 hex chars). Null: no citation syntax —
   *  outbound revision links are skipped entirely. Must carry the g flag
   *  (used with String.matchAll). */
  readonly revisionPattern: RegExp | null;

  /** Web URL of the primary remote as https://host/path (forge-agnostic),
   *  or null when there is no remote to derive. */
  remoteUrl(): string | null;
}
