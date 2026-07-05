---
type: Decision
title: okf VCS Provider Adapters and Forge-Agnostic Revision Links
description: Put all version-control access behind a VcsProvider interface (okflight's vcs/) — git is the first provider, a no-VCS filesystem provider follows — and build outbound revision links from a configurable commit-url-template instead of a hardcoded GitHub URL shape.
tags: [tooling, okf-generalization, vcs]
timestamp: '2026-07-04T00:00:00-07:00'
---

**Status:** active. **Where:**
[`vcs/types.ts`](https://github.com/kriswill/okflight/blob/main/vcs/types.ts) (interface),
[`vcs/git.ts`](https://github.com/kriswill/okflight/blob/main/vcs/git.ts) (git provider),
[`vcs/index.ts`](https://github.com/kriswill/okflight/blob/main/vcs/index.ts)
(discovery/factory). Part of the okf generalization arc
([okf-toml-unified-config](okf-toml-unified-config.md)).

## Context

okf's git usage was scattered through `lib.ts` (root discovery, batched
last-commit dates, `ls-files`, `cat-file` hash verification) and git itself
was a hard requirement — `repoRoot()` exited without it. Outbound commit
links were GitHub-only twice over: `githubRemoteUrl()` rejected any other
origin, and markdown.ts hardcoded the `<url>/commit/<oid>` shape (GitLab
canonically uses `/-/commit/`). A generic okf must run against Perforce or
no version control at all, and link to any forge.

## Decision

- **One interface, `VcsProvider`:** `root`, `trackedFiles()`,
  `lastModified(path)` (null = unknown; callers choose the fallback,
  typically `nowISO()`), `resolveRevisions(candidates)`,
  `revisionPattern` (the citation syntax is the *provider's*, not the
  profile's — git: backticked 7–40 hex spans; null = no citations), and
  `remoteUrl()`. The git provider is the existing batched one-spawn
  implementations moved verbatim.
- **`lib.ts` is now pure text** (frontmatter, links, walk, slugs, ANSI) —
  nothing in it spawns processes; commands get VCS facts from
  `loadContext().vcs`.
- **Forge-agnostic links:** `remoteUrl()` normalizes any https/scp/ssh
  origin to `https://host/path`; okf.toml `[vcs]` (legacy `[repo]` alias
  kept) adds `commit-url-template = "{url}/commit/{hash}"`. The build embeds
  the template with `{url}` pre-substituted; the viewer only fills `{hash}`
  (markdown.ts no longer knows what GitHub is). `repoNameFromUrl` derives
  the header name from any forge, keeping GitLab subgroup chains whole.
- **The "none" filesystem provider**
  ([`vcs/none.ts`](https://github.com/kriswill/okflight/blob/main/vcs/none.ts)) makes okf
  work with no version control at all: tracked files = fs walk minus junk
  names (`.git`, `node_modules`, …) and `[vcs] ignore` globs (+ the
  generated viz output), timestamps = mtime with the same
  newest-under-prefix directory semantics as git, no citations, no remote.
  Selection via `[vcs] provider = "auto" | "git" | "none"`; **auto picks git
  only when the workspace root is a git toplevel** (the git provider's
  batched paths are toplevel-relative — a nested root would mis-key every
  lookup), and an explicit `"git"` on a non-toplevel root fails loudly
  instead of silently degrading to mtime dates (which a later
  `scaffold --force` would bake into every doc). Future providers
  (Perforce, …) implement the same surface.
- **Root discovery is config-first:** the nearest `okf.toml` at or above
  cwd defines the workspace root (resolving the config↔root circularity,
  and enabling monorepo sub-bundles); without one, the git toplevel with
  full defaults — the original zero-config behavior. Neither -> exit 1
  with guidance.
- **Merge commits date their own changes** (`--diff-merges=c` on the
  batched `git log --name-only` pass): git suppresses merge diffs by
  default, so a file introduced during merge conflict resolution — in
  neither parent, e.g. the `pkgs/{cbissue,cbissues,flatpak-user,pass-xdg}.nix`
  quartet added by the `76a05ff` evil merge — had no date at all and fell
  through to the callers' `nowISO()` fallback, making `scaffold --force`
  output nondeterministic. Combined diff lists only paths whose merge
  result differs from **all** parents: evil merges date exactly what they
  introduced, clean merges list nothing, regular commits are unchanged.
  `--diff-merges=first-parent` was rejected — every merge into main
  re-lists everything its branch brought in, so the newest-first map would
  restamp whole PRs with the merge date (and these four files would get the
  later PR-merge date `0b8a629`, not the merge that actually created them).

## Consequences

- Verified: viz commit-link count identical (33/42) before and after — the
  regression this step could most plausibly cause is links silently
  deriving to null; the count is the oracle.
- The `#data` blob gains `commitUrl` (pre-substituted template) alongside
  `repoUrl` (header name); old embeds re-normalize fine (both optional).
- A non-GitHub origin (e.g. Codeberg) now gets real commit links and a real
  header name instead of silently degrading to the fallback name with no
  links.
- `gitISO`'s current-time fallback moved to call sites (`lastModified` may
  be null) — scaffold and viz behavior unchanged.
- Verified without git: a plain directory holding only `okf.toml` +
  `knowledge/` passes validate and builds viz (0 commit links) even with
  git removed from PATH; unit fixtures cover the walk/ignore/mtime
  semantics and auto-selection (git-dependent cases skip in the git-less
  nix check sandbox, which stays green).
- `--diff-merges=c` verified against this repo's history: 11 files gain a
  date (all merge-introduced, previously `nowISO()`), 9 shift to the merge
  date (all genuinely rewritten by `76a05ff`'s conflict resolution — the
  merge *is* their newest content change), everything else identical; two
  `scaffold --force` runs in a scratch worktree now produce byte-identical
  trees. A `gitProvider` fixture test (evil merge) locks in both the fix
  and the cleanly-merged-files-keep-their-dates property.
