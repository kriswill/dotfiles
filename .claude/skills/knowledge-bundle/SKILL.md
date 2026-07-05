---
name: knowledge-bundle
description: Maintain the knowledge/ OKF bundle — the repo's authored knowledge layer (patterns, decision records, playbooks, component catalog). Use after adding or changing modules/packages/hosts, when making a non-obvious design decision worth recording, or when asked to "update the knowledge bundle", "add a decision record", "validate the bundle", or "regenerate the knowledge graph".
---

# Maintaining the knowledge/ OKF bundle

`knowledge/` is an [Open Knowledge Format v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
bundle: markdown concept docs with YAML frontmatter, cross-linked into a
graph. It exists so rationale survives outside commit bodies and chat
history — **keep it current as part of any change, not as an afterthought.**
All conventions live in `knowledge/okf-profile.md`; read it before authoring.

## Commands (okf — nix-built from github:kriswill/okflight)

In the dev shell (`nix develop` / direnv) these are on `PATH` as `okf <cmd>`;
outside it, run `nix run .#okf -- <cmd>`:

```sh
okf scaffold   # stub catalog docs for new modules/packages/hosts/nvim-plugins (never overwrites)
okf index     # regenerate index.md listings (blurbs above first heading are preserved)
okf validate  # conformance + link check; must exit 0 before committing
okf viz      # regenerate knowledge/viz.html interactive graph (gitignored; Svelte 5 viewer — --check typechecks, --perf measures startup)
```

The okf CLI itself is generic; THIS repo's scaffolding logic (module
classes, twins, gating, hosts, nvim plugins) lives in
`knowledge/_okf-scaffold/` — a `main.ts` entry plus one pass file per
scaffolded type (`modules.ts`, `hosts.ts`, `packages.ts`, `nvim.ts`) over a
shared `lib.ts` — wired via `okf.toml [scaffold] script` and run through
the injected `ScaffoldContext` API (vendored type surface:
`knowledge/_okf-scaffold/okf-scaffold-api.d.ts`; the runtime is injected by
`okf scaffold`, so no okf checkout is needed).
Component-scan changes (new source dirs, new doc types, cross-link targets)
are edits to the matching pass file, not to okf itself. The `_` prefix
keeps the directory out of okf's bundle walk.

## When to update what

| Change you just made | Bundle action |
|---|---|
| Added a module / package / host / sub-flake / nvim plugin | `scaffold` then `index`; then bring the stub up to the quality checklist below — scaffolded output is a placeholder, not an entry |
| Removed or renamed a component | Delete/rename its doc under `knowledge/{modules,packages,hosts,nvim/plugins}/`, fix inbound links (`validate` finds them), `index` |
| Changed nvim core config (pack dispatcher, LSP/efm, keymaps, options, filetypes) | Update the matching `knowledge/nvim/*.md` concept |
| Made a non-obvious decision (anything that would deserve a long commit body) | Add `knowledge/decisions/<slug>.md` (template below); cite commit hashes; link affected concepts both ways |
| Changed how a core mechanism works (stow, module discovery, sub-flakes, …) | Update the matching `knowledge/patterns/*.md` |
| New recurring procedure | Add `knowledge/playbooks/<slug>.md` |
| Any of the above | Append a `log.md` entry under today's `## YYYY-MM-DD` (newest first, `**Update**`/`**Creation**`/`**Deprecation**` lead), then run `index` + `validate` |

## Entry quality checklist

Run this before committing any concept doc you created or touched (full
conventions: the Quality bar section of `knowledge/okf-profile.md`;
exemplars: `knowledge/modules/dnsmasq.md`,
`knowledge/nvim/plugins/gitsigns.md`):

- **Description** = what it *is* (upstream-accurate) + how *this repo* uses
  it, in one sentence. No name-restating filler ("X local service", "Kris' X").
- **Body** says what the source can't: wiring, deliberate deviations,
  gotchas. Concise — delete anything that restates the description or the
  code.
- **`## Citations`** links upstream docs / man page; the option reference
  for darwin/nixos modules (nix-darwin manual, search.nixos.org, MyNixOS);
  the `docs/` manual if one exists; commit hashes for decisions. WebFetch
  each URL to confirm it resolves — a guessed link is worse than none.
- **Cross-links** — every concept the body names is a link (enabling host,
  providing overlay/package, module twin, related decisions), with a
  backlink from the target when the relationship is load-bearing. Aim for
  ≥2 edges beyond the scaffolded pattern links.
- **Touched a component whose doc is still a stub?** Upgrade it in the same
  change.

## Decision-record template

```markdown
---
type: Decision
title: <Short Imperative Title>
description: <one sentence — what was decided and the key why.>
tags: [<topic>]
timestamp: '<ISO-8601 now>'
---

**Status:** active. **Where:** [<concept>](../modules/<name>.md).

## Context

<the problem/constraint that forced a choice>

## Decision

<what was chosen, and the mechanics that make it work>

## Consequences

<what got better, what to watch out for>

## Citations

- Commits `<hash>`
```

## Profile rules that trip people up

- Frontmatter requires `type`, `title`, `description`, `timestamp` (ISO-8601).
- Links are **file-relative** (`../modules/nh.md`) — never `/`-rooted; links
  may escape into the repo (`../../modules/...`) but must resolve.
- Body section headings are **H2** (`## Context`, `## Citations`); no H1 in
  concept bodies (frontmatter `title` is the H1).
- Never hand-edit generated `index.md` listing sections — only the blurb
  above the first heading; `viz.html` is generated and gitignored.
