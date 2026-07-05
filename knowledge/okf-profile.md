---
type: Reference
title: OKF Profile
description: This bundle's conventions on top of OKF v0.1 — required fields, link style, resource semantics, entry quality bar, type registry, and tooling.
tags: [okf, meta]
timestamp: '2026-07-04T00:00:00-07:00'
---

This bundle follows [OKF v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
with the profile choices below. Where the draft spec and Google's reference
tooling disagree, we pick one and record it here.

## Profile rules

These rules are enforced from `okf.toml`'s `[profile]` section (defaults in
`flakes/okf/config-cli.ts` reproduce exactly the rules below — this repo's
`okf.toml` therefore sets nothing; another bundle can tune
`required-fields`/`recommended-fields`/`reserved-files`/`rooted-links`/
`repo-links` without touching okf).

- **Required frontmatter:** `type` (hard error when missing/empty; the only
  spec-mandated field, always enforced). `title`, `description`, `timestamp`
  are recommended — warnings, promoted to errors by `okf validate --strict`
  (this matches the reference tooling's stricter validator). `resource` and
  `tags` are encouraged but unchecked.
- **Links are file-relative** (`../modules/nh.md`), never `/`-rooted — the
  spec recommends bundle-absolute links, but they break GitHub rendering, and
  Google's own tooling forbids them. The validator errors on `/`-rooted links
  (`rooted-links = "error"`).
- **Links may escape the bundle** into the repository (`../../modules/...`) to
  point at source files. The validator checks these resolve
  (`repo-links = "check"`); links outside the repository must be full URLs.
- **`resource:`** is a repo-root-relative path to the concept's primary source
  file or directory (e.g. `modules/darwin/nh.nix`) — not a URL, so it survives
  remote renames. Abstract concepts (decisions, playbooks) may omit it.
  `Dual Module` docs (cross-OS twins) point `resource:` at the darwin
  implementation; the body's Source section lists both class files, and the
  scaffolded `timestamp` is the newer of the two twins' last-commit dates.
- **`timestamp`** is ISO-8601, "last meaningful change" — scaffolded docs use
  the source file's last commit date.
- **Body section headings are H2** (`## Schema`, `## Examples`,
  `## Citations`). The spec's examples use H1, but heading level carries no
  OKF semantics, and with a frontmatter `title` a body H1 reads as a second
  title (markdownlint MD025). Generated `index.md` files carry an H1 title.
- **Citations** are a `## Citations` section with a bullet list of markdown
  links (commit hashes cited as `` `abc1234` `` inline).
- **`index.md` files are generated** by `bun flakes/okf/okf.ts index`. The
  prose blurb above the first heading is hand-maintained and preserved on
  regeneration (a directory's parent uses its blurb's first sentence as the
  description); the listing sections are overwritten — don't hand-edit them.
- **`log.md`** is hand-maintained, newest-first, `## YYYY-MM-DD` headings,
  entries lead with `**Creation**` / `**Update**` / `**Deprecation**`.

## Quality bar

A concept doc earns its place by saying what the source can't. Scaffolded
stubs are placeholders, not entries — bring any stub you touch up to this
bar in the same change. Reference shapes: [dnsmasq](modules/dnsmasq.md)
(module), [gitsigns.nvim](nvim/plugins/gitsigns.md) (plugin).

- **Description** — one sentence with two halves: what the thing *is*
  (upstream-accurate) and how *this repo* uses it. "dnsmasq local DNS
  service" fails; "dnsmasq — lightweight DNS forwarder/cache, configured
  here as a loopback-bound local resolver for custom hostnames" passes.
- **Body** — concise and specific: a sentence or two on what the component
  is, then the non-obvious part — how the repo wires it, deliberate
  deviations from defaults, constraints and gotchas. Cut anything that
  restates the description or the source code; a body that only repeats the
  description isn't done.
- **Citations** — link where authority actually lives: upstream project
  docs / man page; the option reference for darwin/nixos modules
  (nix-darwin manual, search.nixos.org, MyNixOS); the in-repo `docs/`
  manual when one exists; commit hashes for decisions. Verify every URL
  resolves before citing — never guess a link.
- **Cross-links (network binding)** — link every concept the body names:
  the host that enables it, the overlay/package that provides it, the twin
  module, the decisions that shaped it. Add the backlink from the target
  when the relationship is load-bearing. The scaffolded pattern links alone
  don't bind a doc into the graph — a well-bound doc carries at least two
  edges specific to it.

## Type registry

Free-form per the spec; this bundle currently uses: `Pattern`, `Decision`,
`Playbook`, `Darwin Module`, `NixOS Module`, `Dual Module` (a cross-OS twin —
one doc covering the parallel darwin + nixos implementations), `Flake-parts
Module`, `Host`, `Nix Package`, `Overlay`, `Sub-flake`, `Neovim Plugin`,
`Neovim Config`, `Reference`. Add new types sparingly and list them here.

## Tooling

All bun/TypeScript in [`flakes/okf/`](../flakes/okf/) — the CLI itself is
dependency-free; the viz viewer is a Svelte 5 app bundling three +
postprocessing (deps in `flakes/okf/package.json`, `bun install`ed on
demand). In
the dev shell (`nix develop` / direnv) it's on `PATH` as **`okf`** via the
[dev](modules/dev.md) module; outside it, invoke with bun directly:

```sh
okf scaffold [--force]   # run this repo's scaffolder (scripts/okf-scaffold.ts via okf.toml [scaffold]; idempotent; --force overwrites)
okf index               # regenerate index.md listings
okf validate [--strict]  # spec + profile conformance; --strict fails on warnings too
okf viz [--check|--perf] # render knowledge/viz.html (Svelte 5 viewer); --check runs svelte-check on tsgo, --perf measures startup in headless Chrome
okf help [command]      # full usage, per-command flags, docs pointers

bun flakes/okf/okf.ts <cmd>   # equivalent, no dev shell needed
```

`viz.html` is generated output and gitignored — regenerate at will. Every
`okf viz` run prints build-phase timings; the page records startup marks on
`window.__okf.perf`. The viewer app (`flakes/okf/viz-app/`) has bun tests
(`cd flakes/okf && bun test`). Repo-specific strings and settings (header,
facet filters (0..n `[facet.<name>]` lenses), type taxonomy, legend groups,
embed cap, bundle dir) come from the optional repo-root
[`okf.toml`](../okf.toml) — one config file read by **all** okf commands
(loaded by `flakes/okf/config-cli.ts`, strict-validated; a malformed file
fails every command); without it okf works with generic fallbacks (see the
[viz-config-toml](decisions/viz-config-toml.md) and
[okf-toml-unified-config](decisions/okf-toml-unified-config.md) decisions). The graph is
published as public documentation at <https://kris.net/dotfiles/> — rebuilt
and deployed by GitHub Pages CI (`.github/workflows/pages.yml`) on every
push.

## Citations

- [OKF SPEC.md](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
- [How the Open Knowledge Format can improve data sharing](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing)
