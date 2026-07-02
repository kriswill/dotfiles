---
type: Reference
title: OKF Profile
description: This bundle's conventions on top of OKF v0.1 — required fields, link style, resource semantics, type registry, and tooling.
tags: [okf, meta]
timestamp: '2026-07-02T00:00:00-07:00'
---

This bundle follows [OKF v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
with the profile choices below. Where the draft spec and Google's reference
tooling disagree, we pick one and record it here.

## Profile rules

- **Required frontmatter:** `type`, `title`, `description`, `timestamp` on
  every concept (the spec requires only `type`; this matches the reference
  tooling's stricter validator). `resource` and `tags` are recommended.
- **Links are file-relative** (`../modules/nh.md`), never `/`-rooted — the
  spec recommends bundle-absolute links, but they break GitHub rendering, and
  Google's own tooling forbids them. The validator errors on `/`-rooted links.
- **Links may escape the bundle** into the repository (`../../modules/...`) to
  point at source files. The validator checks these resolve; links outside the
  repository must be full URLs.
- **`resource:`** is a repo-root-relative path to the concept's primary source
  file or directory (e.g. `modules/darwin/nh.nix`) — not a URL, so it survives
  remote renames. Abstract concepts (decisions, playbooks) may omit it.
- **`timestamp`** is ISO-8601, "last meaningful change" — scaffolded docs use
  the source file's last commit date.
- **Body section headings are H2** (`## Schema`, `## Examples`,
  `## Citations`). The spec's examples use H1, but heading level carries no
  OKF semantics, and with a frontmatter `title` a body H1 reads as a second
  title (markdownlint MD025). Generated `index.md` files carry an H1 title.
- **Citations** are a `## Citations` section with a bullet list of markdown
  links (commit hashes cited as `` `abc1234` `` inline).
- **`index.md` files are generated** by `bun scripts/okf/okf.ts index`. The
  prose blurb above the first heading is hand-maintained and preserved on
  regeneration (a directory's parent uses its blurb's first sentence as the
  description); the listing sections are overwritten — don't hand-edit them.
- **`log.md`** is hand-maintained, newest-first, `## YYYY-MM-DD` headings,
  entries lead with `**Creation**` / `**Update**` / `**Deprecation**`.

## Type registry

Free-form per the spec; this bundle currently uses: `Pattern`, `Decision`,
`Playbook`, `Darwin Module`, `Flake-parts Module`, `Host`, `Nix Package`,
`Overlay`, `Sub-flake`, `Reference`. Add new types sparingly and list them
here.

## Tooling

All zero-dependency bun/TypeScript in [`scripts/okf/`](../scripts/okf/):

```sh
bun scripts/okf/okf.ts scaffold   # stub catalog docs from the repo (idempotent)
bun scripts/okf/okf.ts index     # regenerate index.md listings
bun scripts/okf/okf.ts validate  # spec + profile conformance; exit 1 on errors
bun scripts/okf/okf.ts viz      # render knowledge/viz.html interactive graph
```

`viz.html` is generated output and gitignored — regenerate at will.

## Citations

- [OKF SPEC.md](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
- [How the Open Knowledge Format can improve data sharing](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing)
