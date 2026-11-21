---
type: Decision
title: Build herdr-md as Two bun Bundles and Link Them from the Store
description: 'herdr-md (a markdown viewer mod for Herdr, with its mdh CLI) is pinned upstream source plus pinned npm dependencies, built by bun into one main.js and one render.js. The mod is one file because Herdr refuses imports that resolve outside a mod''s folder, and the renderer is one file so that bun can run it without 430 MB of node_modules or Node.'
tags: [herdr, bun, packaging, mods]
status: stable
generated: { by: claude-code/fable-5.2, at: 2026-11-20T22:50:00-08:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/herdr/README.md
    title: 'flakes/herdr/README.md, "The markdown viewer" (what is built, how it is installed, updating)'
  - id: herdr-md-readme
    resource: https://github.com/ryanthedev/herdr-md/blob/e96cc755eb1afd18209822b638f1e7664685193e/README.md
    title: 'ryanthedev/herdr-md README at the pinned commit (install by copy, npm install on first figure, what it runs)'
  - id: herdr-md-render
    resource: https://github.com/ryanthedev/herdr-md/blob/e96cc755eb1afd18209822b638f1e7664685193e/mods/herdr-md/render/render.mjs
    title: 'herdr-md render.mjs at the pinned commit (the batch renderer: MathJax to SVG, mermaid-cli to PNG)'
  - id: mermaid-cli-index
    resource: https://github.com/mermaid-js/mermaid-cli/blob/11.4.2/src/index.js
    title: 'mermaid-cli 11.4.2 src/index.js (the page and two scripts it loads from beside its own source)'
  - id: bun-bundler
    resource: https://bun.com/docs/bundler
    title: 'Bun bundler (bun build: --target, --external, --compile)'
---

**Where:** [herdr](../packages/herdr.md) (`pkgs/herdr-md.nix`,
`pkgs/herdr-md-linux.patch`, `programs.herdr-md`); enabled on
[nebula](../modules/nebula-herdr.md). The keys that open a viewer are in the
stowed `keys.json` ([config via stow](herdr-app-config-via-stow.md)).

## Context

Upstream installs herdr-md by copying `mods/herdr-md` into
`~/.config/herdr-app/mods`. The first formula or diagram then makes the mod
run `npm install` in its `render/` folder, and it runs the renderer with
whatever `node` is on the app's PATH.[^herdr-md-readme] It is built and
tested on macOS only. A first install on nebula was that copy, patched by
hand for Linux: 436 MB, untracked, and gone with the next reinstall.

Three facts about Herdr shaped the package:

- A mod can only be JavaScript that Herdr's own engine loads. What a mod
  runs with `exec` can be any program.
- Herdr writes its typings into every mod folder at start, and herdr-md
  keeps its cache in its own folder (`.cache`, reached through `appHome()`).
  So the folder can't be a link into the store.
- Herdr refuses an import that resolves outside the mod's folder. A folder
  of links to the store build failed `herdr-app check` with ``module
  `./lex.js` resolves outside the application directory``. `main.js` itself
  may be a link, as every stowed mod's is.

## Decision

Two pinned fetches: the repo at a commit, and the renderer's npm
dependencies from upstream's lock file (`fetchNpmDeps`). Then our Linux
patch, and two `bun build` runs:[^bun-bundler]

- **`main.js`**: the mod's eight modules as one file, with only Herdr's own
  modules (`gpui-kit`, `gpui-base`, `herdr`) left as imports. The NixOS and
  nix-darwin modules link `main.js`, `mdh` and `mod.json` by name into a
  real `~/.config/herdr-app/mods/herdr-md` (tmpfiles `L+`, or `ln -sfn` at
  activation). The package lists those names as `modFiles`, so no
  import-from-derivation is needed to learn them.
- **`render.js`**: `render.mjs` with MathJax, mermaid-cli and puppeteer (838
  modules) as one 6 MB file.[^herdr-md-render] The mod runs it with bun,
  both by store path. mermaid-cli makes the browser load a page and injects
  two scripts that it finds beside its own source, which a bundle has none
  of; they are installed under `libexec/herdr-md/mermaid`, and its three
  lookups are substituted to point there.[^mermaid-cli-index]

Node stays in the build, where nixpkgs' npm hook unpacks the dependencies,
and `disallowedReferences` keeps it out of the closure.

Rejected:

- **Copy the files at activation.** tmpfiles can't replace a file with a
  newer copy without removing it first, so every switch would reload open
  viewers. Links that already point at the right path are left alone.
- **`bun build --compile` for the renderer.** It works with the same asset
  substitution, but the executable is 110 MB: the same 6 MB of JavaScript
  inside another copy of the bun these machines already have.
- **A `bun install` fixed-output derivation.** The dependencies include
  per-platform prebuilt addons (`@napi-rs/canvas`), so its hash would differ
  per system and could move with bun's version. npm's tarball cache is the
  same everywhere.

## Consequences

The package is 22 MB and 85 files, and on nebula it adds nothing else to the
closure (bun, python3 and ffmpeg-headless were already there). Formulas and
Mermaid diagrams were drawn from the store build in a live window, with only
Helium and coreutils on the renderer's PATH.[^subflake-readme]

To watch on an update:

- The build fails if the Linux patch, a substitution in `main.js` or one of
  mermaid-cli's three lookups no longer applies, or if upstream ships a file
  that nothing places.
- The sandbox has no browser, so the install check renders only a formula.
  Draw one Mermaid diagram by hand after a bump.
- Stack traces from the mod name lines of the bundle, not of upstream's
  files.
- The Macs don't enable `programs.herdr-md` yet. The shared `keys.json`
  already binds the keys, which do nothing useful there until they do.

[^subflake-readme]: `flakes/herdr/README.md`, "The markdown viewer"
[^herdr-md-readme]: herdr-md README: Install, Needs, What it runs
[^herdr-md-render]: herdr-md `render.mjs`: `math()` and `mermaid()`
[^mermaid-cli-index]: mermaid-cli `src/index.js`: `mermaidIIFEPath`, `zenumlIIFEPath`, `mermaidHTMLPath`
[^bun-bundler]: Bun bundler documentation
