---
type: Decision
title: okf VCS Provider Adapters and Forge-Agnostic Revision Links
description: Put all version-control access behind a VcsProvider interface (flakes/okf/vcs/) — git is the first provider, a no-VCS filesystem provider follows — and build outbound revision links from a configurable commit-url-template instead of a hardcoded GitHub URL shape.
tags: [tooling, okf-generalization, vcs]
timestamp: '2026-07-04T00:00:00-07:00'
---

**Status:** active. **Where:**
[../../flakes/okf/vcs/types.ts](../../flakes/okf/vcs/types.ts) (interface),
[../../flakes/okf/vcs/git.ts](../../flakes/okf/vcs/git.ts) (git provider),
[../../flakes/okf/vcs/index.ts](../../flakes/okf/vcs/index.ts)
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
- Future providers (Perforce, and the "none" filesystem provider that makes
  okf work without version control) implement the same surface; provider
  selection via `[vcs] provider` arrives with the second provider.

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
