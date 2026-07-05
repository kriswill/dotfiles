# Log

## 2026-07-04

- **Update** — [okf](packages/okf.md): `okf viz` detail-panel dates are now
  human-friendly, driven by a new `display.date-format` in `okf-viz.toml`
  (`"iso"` default = as written, `"us"` "Jul 3, 2026", `"international"`
  "3 Jul 2026"; this repo sets `"us"`). Applies to date-shaped frontmatter
  values (full-match only — prose containing a date is untouched) and the
  file/dir "last commit" rows. Formatting reads the literal Y-M-D, never a
  `Date()` timezone conversion, so `2026-07-04T00:00:00-07:00` shows Jul 4
  for every viewer (helper: `flakes/okf/viz-app/dates.ts`).

- **Update** — [podman](packages/podman.md),
  [podman-desktop](modules/podman-desktop.md): both upgraded from stubs to
  the quality bar. New load-bearing context: the primary workload is
  **minikube's podman driver for work Kubernetes** (minikube itself is not
  nix-managed; k9s rides along per host). podman gains the packaging
  rationale summary (FOD of the official darwin_arm64 zip, dontFixup for
  the adhoc signature, bundled vfkit/gvproxy, applehv-over-libkrun
  backend), podman-desktop the thin-module explanation (`/libexec`
  pathsToLink because `os.Executable` isn't symlink-resolved) and the
  settings.json stow-with-git-filter twist (in-place rewrite, verified
  live symlink, contrasted with
  [snapshot-synced configs](patterns/snapshot-synced-configs.md)). Both
  cite official sites + the minikube podman-driver docs and link the
  enabling hosts.

- **Creation** — [svelte-language](svelte-language.md),
  [markdown-language](markdown-language.md): the last two language
  References. Svelte: the viz-app is the one Svelte codebase (Svelte 5
  runes, Bun.build-bundled, svelte-check + bun test), with the
  `docs/svelt/` manual's "always write runes, translate Svelte-4 content"
  ground rule surfaced; backlinked from [nvim LSP](nvim/lsp.md),
  [typescript-language](typescript-language.md), [okf](packages/okf.md),
  and [manuals](manuals.md). Markdown: the documentation language —
  OKF-profile dialect rules (H2 bodies, file-relative links for GitHub),
  rumdl via efm with the load-bearing MD013-disabled rationale from
  `rumdl.toml`, glow + viz-app rendering paths.

- **Creation** — [typescript-language](typescript-language.md),
  [lua-language](lua-language.md), [bash-language](bash-language.md):
  the language-Reference series continues from
  [nix-language](nix-language.md). TypeScript: default tooling language,
  bun-executed with no tsc step, vtsls/svelte-server file ownership split,
  biome formatting. Lua: exclusively the Neovim config (LuaJIT / 5.1
  dialect), stylua + lua-ls/lazydev. Bash: the glue layer bounded by zsh
  (interactive) and bun+TS (new tooling), strict mode + shellcheck both
  in-editor and at build time inside `writeShellApplication`. Backlinked
  from [nvim LSP](nvim/lsp.md) (per-server bullets),
  [nvim architecture](nvim/architecture.md), and
  [bun-runtime](bun-runtime.md).

- **Creation** — [bun-runtime](bun-runtime.md): root-level Reference
  concept for Bun — the repo's default script runtime (house rule: bun + TS
  over bash/python for tooling), per-OS provisioning
  ([user-packages](modules/user-packages.md) on darwin,
  [node-runtime](modules/node-runtime.md) on NixOS), and the three
  consumption modes: run-from-source ([okf](packages/okf.md)),
  compile-to-binary ([ccglass](packages/ccglass.md)), and outside-nix
  ([qmd-sqlite](modules/qmd-sqlite.md)'s qmd). Backlinked from all six of
  those plus [dev](modules/dev.md); [user-packages](modules/user-packages.md)
  upgraded from scaffold stub in passing (boy-scout rule), and
  [ccglass](packages/ccglass.md) gained its bun-compile provenance and a
  [bump-ccglass](playbooks/bump-ccglass.md) link.

- **Creation** — [nix-language](nix-language.md): root-level Reference
  concept for the Nix language itself — evaluator choice (Determinate Nix,
  for ≥ 2.26 path-input locking), laziness as the mechanism behind the
  shared-overlay rule, dendritic idioms, and the deadnix/statix/nixfmt +
  nil_ls toolchain. First concept authored against the new quality bar;
  backlinked from [dev](modules/dev.md).

- **Update** — [okf-profile](okf-profile.md): added a **Quality bar**
  section codifying what a finished concept doc looks like — two-half
  descriptions (what it is + how this repo uses it), bodies that say what
  the source can't, verified citations to upstream docs / option
  references / in-repo manuals, and cross-linking expectations (≥2
  doc-specific edges, backlinks for load-bearing relationships). The
  `knowledge-bundle` skill gained the matching pre-commit checklist and
  now treats scaffolded stubs as placeholders to upgrade on touch.
  Exemplars: [dnsmasq](modules/dnsmasq.md),
  [gitsigns.nvim](nvim/plugins/gitsigns.md).

- **Update** — [dnsmasq](modules/dnsmasq.md): filled in the previously
  stub description with what dnsmasq actually is (lightweight DNS
  forwarder/cache + DHCP/router-advertisement/network-boot infra) and how
  this repo uses it (loopback-bound local resolver for `localhost`/`p4c`,
  not a network-facing server); added `## Citations` linking the upstream
  docs, man page, and the nix-darwin `services.dnsmasq` option reference.

- **Creation** — [okf-subflake](decisions/okf-subflake.md): okf moved
  `scripts/okf/` → `flakes/okf/` (`git mv`, history preserved) and became a
  real sub-flake: `packages.<system>.okf` ships sources + vendored
  `node_modules` (fixed-output `bun install`, one hash for all systems) under
  a `bun run --no-install` wrapper; `checks.<system>.test` runs the 238
  viewer tests offline. `lib.ts` `repoRoot()` is now cwd-based
  (`git rev-parse --show-toplevel`) so the store binary operates on the
  caller's repo — the only generalization taken now. Dev shell keeps the
  impure working-tree wrapper (fast iteration unchanged); the Pages workflow
  stays bun-native with paths repointed. Root wiring per the house pattern
  (relative-path input + follows, packages.nix re-exports incl.
  aarch64-linux; no overlay). New [okf](packages/okf.md) catalog concept;
  `scripts/okf` references swept across AGENTS.md/README/skills/knowledge
  (log history left as-is).

- **Update** — `okf-viz.toml`'s `platform` facet values renamed
  `darwin`/`nixos` → `macos`/`linux` (`[facet.platform]` `values`, and the
  RHS of `.types`/`.ids`/`.nix-packages.guards`) for canonical platform
  naming — `nixos` is one specific Linux configuration and `darwin` is the
  macOS kernel name, not a name a non-engineer would use for the OS. Guard
  **keys** (`darwin`/`linux`, the `optionalAttrs` predicate substrings
  matched against `modules/packages.nix`) are unchanged, as are the concept
  *type* taxonomy (`Darwin Module`/`NixOS Module`/`Dual Module`) and tags
  (`darwin-module`/`nixos-module`) — those name the Nix module class, not
  the platform, and were kept as-is by design. No `knowledge/*.md`
  front-matter changed: the facet resolves per concept at viz build time
  and was never hand-authored. Old deep links (`?platform=darwin|nixos`,
  legacy `?os=darwin|nixos`) now silently clamp to `all` on decode — accepted,
  since `knowledge/viz.html` is gitignored and locally regenerated. Verified
  by the full 232-test `scripts/okf` suite, `okf viz`, and `okf validate`.

- **Creation** — [viz-config-toml](decisions/viz-config-toml.md): every
  repo-specific string and setting in the viz moved out of the code into an
  optional repo-root `okf-viz.toml` (exhaustive scope — display strings, 0..n
  `[facet.<name>]` filter lenses (dogfooded here as a single darwin/nixos
  `platform` facet, incl. the `modules/packages.nix` guard parse and a
  host-id override), the type/legend taxonomy, embed cap, bundle dir, output
  name, repo-URL override) — the first step toward other projects consuming
  the viewer for their own OKF bundles. One shared module
  (`viz-app/config.ts`) normalizes strictly at build (`Bun.TOML.parse`,
  unknown keys/dangling refs fail with their key path) and leniently in the
  app off the `#data` blob; without okf-viz.toml the viewer builds generic (no
  facet controls, alphabetical types with generated colors, flat legend,
  "OKF bundle" header). Each facet resolves per concept — an id override,
  then an opt-in nix-packages guard map, then a frontmatter key, then a type
  table, else **unresolved** (always visible) — replacing the `both`/
  `neutral` sentinels an earlier pass of this same config had used; a legacy
  `os=` hash param still decodes for a facet literally named `platform`.
  `TYPE_ORDER`/`GROUP_OF_DIR`/`GROUP_ORDER`/`NIXOS_HOSTS` deleted from
  `data.ts`; `markdown.ts` lost its hardcoded `knowledge/` prefix +
  `slice(10)` offsets; pages CI now also triggers on `okf-viz.toml`. Verified
  by 232 bun tests (incl. a config suite, a generic-mode suite, and a
  multi-facet AND-visibility suite), `okf viz --check` clean, parity build
  with the checked-in okf-viz.toml (per-node resolution diffed against the
  pre-facets baseline), a generic build with it moved aside, and a
  headless-Chrome `--perf` boot of the built page.

- **Update** — viz header now says what the page is: the sidebar h1 reads
  "`owner/repo` OKF viz" (derived in `buildModel` from the embedded GitHub
  `repoUrl` via `repoNameFromUrl`; falls back to "knowledge/ OKF viz" without
  an origin) with a small focusable (?) whose hover bubble explains the bundle
  and links the OKF spec, and the document `<title>` matches
  ("kriswill/dotfiles — OKF knowledge graph"). Verified by 177 bun tests
  (3 new: repoName derivation + Sidebar header/fallback mounts) and
  `okf viz --check`.

## 2026-07-03

- **Update** — viz filter UX, phase D (pinned sidebar tree), on top of phases
  A–C. Selecting a concept now pins it at the top of the sidebar list with
  its linked concepts nested beneath by hop distance — direct links one
  indent in, 2-hop isolation adds a second level, and with isolation off a
  divider separates the remaining visible concepts (flat, alphabetical) —
  replacing the flat alphabetical reshuffle that let the focused node float
  around under filter changes. The nesting is a deterministic BFS tree
  (`conceptTree`/`treeIds` in `viz-app/data.ts`): each node attaches to its
  alphabetically-first previous-layer neighbor (title then id tie-break),
  siblings sort alphabetically, filtered-out intermediates are spliced out
  with their visible descendants promoted to the nearest visible ancestor,
  and the anchor stays pinned even when it fails the active filters. Rows
  connect dot-to-dot with quarter-circle CSS elbows (border-radius
  pseudo-elements on the row wrappers, no SVG) in each child row's own type
  color, plus muted `color-mix` rails continuing to later siblings — the
  first `{#snippet}`/recursive-render use in the viewer. Anchored on
  `focusedConcept`, so the pin survives file/dir views (isolation suspends
  there and the layout falls back to direct-links + rest). `visibleSorted`
  is untouched (sidebar counter and existing tests unaffected); a new
  `listing = { tree, rest }` derived feeds `ConceptList` only. Verified by
  174 bun tests (16 new across data/state/components), `okf viz --check`,
  and a headless-Chrome drive (structural snapshots at off/1-hop/2-hop +
  light/dark close-ups of the connector geometry).

- **Creation** — [gh-op](packages/gh-op.md) overlay: on Linux, gh is wrapped
  to source `GH_TOKEN` from 1Password at runtime (`op read` of the "GitHub gh
  CLI token" item), and the plain-text oauth token was removed from
  `~/.config/gh/hosts.yml` (`gh auth logout`) — no gh secret at rest on
  nebula's unencrypted disk. One wrapper covers both the CLI and git's
  `!gh auth git-credential` helper; darwin passes through untouched. `op` is
  called by bare name so it resolves to the NixOS setgid wrapper.

- **Update** — [nebula](hosts/nebula.md) gained a "Firmware quirks" section:
  the warm-reboot DRAM-training hang (debug code 44 + yellow DRAM LED on BIOS
  `2.A02`; userspace shutdown was clean, the firmware stalled re-training DDR5
  — cold cycle clears it; fix = BIOS update past `2.A02` or Memory Context
  Restore), plus the standing `Wake Up Event By = OS` suspend fact with the
  reminder that a BIOS flash resets it.

- **Update** — `config/` snapshot capture is now automatic on nebula: one
  systemd user `.path` unit per app (gh, noctalia, helium — defined beside
  each app's package wiring) watches the live files with `PathChanged=`
  (inotify; systemd watches parent dirs, so the watch survives atomic-rename
  inode swaps) and runs `<app>-config capture` after a short sleep-debounce
  (deliberately not `TriggerLimit*`, which fails the path unit outright when
  exceeded). Helium's service skips while the browser runs — live SQLite
  (Cookies/Login Data) could snapshot torn; Chromium's exit-time writes
  re-trigger the capture. gh gets a launchd `WatchPaths` twin on darwin
  (dir-watch: launchd kqueue file-watches are inode-based). Capture never
  writes the live file, so restore→capture can't loop; commits stay manual.

- **Creation** — gh's `config.yml` moved from the stow tree (`home/gh/`,
  deleted) to the `config/` snapshot pattern with a new
  [gh-config](packages/gh-config.md) CLI (capture/restore/diff), because gh
  rewrites its config via atomic rename — the same save pattern as
  Helium/Noctalia — which had broken the stow link and silently skipped the
  gh package on every rebuild. First cross-platform snapshot app: the CLI
  ships via the [git](modules/git.md) twins on both OSes; `hosts.yml` (auth)
  stays untracked. Fresh machines run `gh-config restore` once.

- **Creation** — nebula's Nix implementation swapped from Lix to Determinate
  Nix via the new [determinate](modules/determinate.md) nixos-class module
  (imports the determinate flake input's NixOS module; snowglobe-lib unforked —
  its `setDefault`/1337 `nix.package = lix` loses to the module's plain
  assignment). Motive: Lix lacks Nix ≥2.26 relative-path input locking
  (lix#641, Flakes frozen), so the `./flakes/*` sub-flake inputs re-locked to
  machine-local store paths on every rebuild, churning `flake.lock` twice per
  `nrs` plus every direnv reload. The lock's sub-flake nodes are now stable
  relative paths with a `parent` field; lazy trees also stop the dirty-tree
  store copies. Full rationale:
  [Replace Lix With Determinate Nix](decisions/lix-to-determinate.md).

- **Update** — viz filter UX, phase C (platform axis), on top of phases A/B.
  A segmented `all | darwin | nixos` control below the legend filters the
  graph by which OS a concept applies to; `darwin` shows darwin + dual +
  neutral concepts (hiding nixos-only), `nixos` the mirror, `all` everything —
  composed via AND with the type/search/neighborhood filters, riding the URL
  as `?os=darwin|nixos`. The platform of each concept is **derived from repo
  structure**, not hand-authored: modules by `type` (Darwin/NixOS/Dual/
  Flake-parts), hosts by host-id (nebula = nixos, rest = darwin), nvim = both,
  knowledge = neutral, and packages by parsing the darwin/linux
  `lib.optionalAttrs` guards in `modules/packages.nix` (a brace-depth,
  depth-aware scan baked into the graph at build time by `viz.ts`). Known
  limitation: `noctalia-config`/`helium-config` build unconditionally
  (file-copy scripts) so they classify `both` despite being Linux-desktop
  tools — the direct consequence of deriving from build structure. Verified
  and reviewed through a multi-agent workflow (svelte-check + a headless-Chrome
  drive incl. a 3D-scene-dim probe, in parallel with a 3-dimension adversarial
  review); the review found no correctness bugs — the four confirmed
  low-severity findings (a stale hash header comment, an unexercised parser
  edge, a not-quite-pinned replaceState test, and `.seg`/`.hint` CSS
  duplicated across the two segmented controls) were all fixed: the parser is
  now depth-aware against nested `callPackage` args, and the shared control
  primitives were hoisted into the global stylesheet. Still deferred: a
  `platform:` frontmatter field, knowledge-doc platform lean, and a
  platform-suppressed-matches note.

- **Update** — viz filter UX, phase B (grouped legend + neighborhood
  isolation), on top of phase A. The 14-type legend clusters into 4 groups
  (Knowledge/System/Packages/Neovim) derived from each concept's bundle
  directory (a new `dirOf`/`GROUP_OF_DIR` map, zero hand-authored per-type
  taxonomy) — group headers get their own toggle-whole-cluster / alt-click-
  solo-cluster, alongside the existing per-type controls. Selecting a
  concept now shows a 1-hop/2-hop/off control that restricts the sidebar
  (and the 3D scene's dimming) to its graph neighborhood, ANDed with the
  type/search filters, sticky across concept-to-concept clicks but
  suspended while a file/dir view is open; `?isolate=1|2` joins `hide=`/`q=`
  in the URL. Implemented directly (the two commits are too interdependent
  for parallel-agent authorship) but verified and reviewed through two
  multi-agent workflow passes — one per commit, each running svelte-check +
  a real headless-Chrome interaction drive in parallel with a 3-dimension
  adversarial code review. Both passes found genuine issues before commit:
  phase's first pass caught a dormant non-deterministic bug (a type's
  legend group depended on node array order) and an undetected regression
  risk in the group-toggle logic; the second caught a misleading sidebar
  count during sticky-but-inactive isolation, a real high-severity test gap
  (no test drove opening a file view while isolated), a duplicated
  id-resolution derivation, and a component class name collision — all
  fixed, with tests pinning the corrected behavior. Deferred: the platform
  (darwin/nixos/dual) facet, collapsible legend groups, an isolation-
  suppressed-matches note parallel to phase A's type-filter one.

- **Update** — viz filter UX, phase A (quick wins). The legend gains
  all/none header links and alt-click-to-isolate (one click instead of
  N−1 toggles); the search haystack now includes frontmatter `tags` and the
  placeholder says what it filters (title/type/tag — it always also matched
  id and description); the counts line goes live ("42 of 131 concepts")
  whenever a filter is active; search hits suppressed by a hidden type
  surface as a clickable "+n hidden by type filters" note instead of
  silently vanishing; and the whole lens (hidden types + query) now rides
  the URL hash behind the selection (`c/<id>?hide=A,B&q=…`) — filter-only
  changes amend the history entry via `replaceState`, selection changes
  still push, so Back walks selections and shared links reproduce the view.
  Phase B (grouped legend matching the bundle topology, neighborhood
  isolation) is planned separately.

- **Update** — `okf viz` links commit-hash citations to GitHub. `` `abc1234` ``
  code spans (the profile's citation convention) in concept bodies and
  embedded markdown now render as outbound `github.com/…/commit/<full-oid>`
  links. Every candidate is verified against the local repo in one
  `git cat-file --batch-check` pass, so doc examples, other repos' revs
  (nixpkgs, snowglobe-lib, noctalia pins), and commits purged by the helium
  history rewrite stay plain code instead of 404ing (31 of 40 spans link
  today). No GitHub origin → everything degrades to plain code.

- **Update** — `okf viz` learned directories. Concept links and `resource:`
  paths that point at a git-tracked directory (sub-flakes like
  `flakes/ccglass/`, stow packages like `home/git/`, nvim spec trees)
  previously rendered as dead title-only anchors; they now open an in-panel
  directory listing (immediate subdirs + files with line/size metadata, every
  tracked descendant embedded and clickable, `d/<path>` deep links, back-link
  and Referenced-by intact). Trees are walked via `git ls-files`, so
  untracked junk never leaks in; the existing 200 KB/binary embed caps still
  apply — oversized files are listed as "not embedded".

- **Update** — applied all fifteen xhigh code-review findings on the
  reorientation pass. `okf scaffold` hardened: per-class gating is no longer
  flattened across a twin's two implementations (a gated darwin module with
  an ungated nixos twin now gets per-class mount clauses), host class is
  detected from the comment-stripped registration instead of a raw substring
  (with loud warnings replacing the silent darwin fallback), twin timestamps
  take the newer of the two files' commit dates (`resource:` stays on the
  darwin file — convention recorded in the [profile](okf-profile.md)),
  dangling symlinks in host dirs are skipped instead of crashing the walk,
  and NixOS host docs now say "host-specific files" rather than claiming
  opt-in features. Content fixes: node-runtime's false "no module provides
  bun on macOS" claim corrected (user-packages carries bun + nodejs_24),
  cbissue's nonexistent "my-packages overlay" replaced with the real
  per-package overlays (source comment fixed in place too), the stale
  home-manager header comment in the nixos tmux twin fixed at source, the
  mkOrder-1600/tmpfiles link mechanics deduped to the authoritative
  [store-path configs pattern](patterns/store-path-configs.md), the
  users-k-helium/noctalia docs now link
  [snapshot-synced configs](patterns/snapshot-synced-configs.md) instead of
  restating it, and helium's capture list was corrected everywhere to include
  Cookies/Login Data — age-encrypted credentials in the repo, not
  "secrets never enter the repo". Version pins were dropped from
  [manuals.md](manuals.md) (versions live in the manuals, which lead with
  verified state).

- **Update** — bundle-wide dual-OS reorientation pass (the merge's knowledge
  debt): `okf scaffold` now scans `modules/nixos/` alongside `modules/darwin/`
  (types `NixOS Module` / `Dual Module` added to the
  [profile registry](okf-profile.md)), detects each host's class instead of
  assuming darwin, and recurses into nested host files
  (`nebula/users/k/*.nix`). That surfaced nine uncatalogued components; all
  were scaffolded and enriched. The 11 cross-OS twins (git, tmux, zsh, nh, …)
  were retyped `Dual Module` with both sources and their per-OS differences
  documented; nebula's 12 host-file docs were retyped from the erroneous
  `Darwin Module` and enriched from source; hosts/nebula.md lost its "imports
  every darwin module" claim. Three new patterns:
  [cross-OS module twins](patterns/cross-os-module-twins.md),
  [snapshot-synced configs](patterns/snapshot-synced-configs.md), and
  [host registry & realisers](patterns/host-registry-realisers.md); the four
  existing patterns now speak for both classes. Playbooks gained nixos
  variants (rebuild/rollback, add-module, add-package, adopt-dotfile); five
  pre-merge decisions got dated amendments. New
  [manuals reference](manuals.md) makes the `docs/` layer reachable from the
  knowledge graph, and module docs now link their manuals. Everything
  adversarially verified against source (three factual defects found and
  fixed, incl. AGENTS.md's stale claim that `home/diffnav` deploys
  everywhere — it is skip-listed on darwin).

- **Creation** — recorded the
  [vesktop pnpm whitelist decision](decisions/vesktop-pnpm-whitelist.md):
  nixpkgs' vesktop deliberately pins the CVE-flagged pnpm-10.29.2 (newer pnpm
  crashes its electron-builder), so nebula tolerates a scoped
  `permittedInsecurePackages` entry for now; the whitelist-free exit (AppImage
  repack à la wowup + `programs.discord.package`) is written down for when
  it's needed.

- **Milestone** — merged the orphan `nebula-snowglobe` branch into one dual-OS
  flake ([decision](decisions/nixos-darwin-unification.md)): three darwin
  hosts + the `nebula` NixOS desktop build from a single flake on one
  `nixos-unstable` nixpkgs. `home/` is now shared with per-OS skip lists in
  the stow modules ([decision](decisions/stow-os-skip-lists.md)); shared git
  config unified (aliases + difftastic + delta + codeberg helper); ghostty
  split into shared config + generated per-OS `os.conf`; nvim tree
  reconciled on main's (newer) copy. NixOS twins added for nh, git, direnv,
  direnv-nom, ghostty (nebula's direnv had been transitive-only); nebula's
  `packages/` dissolved into `pkgs/` + overlays. sops-nix now runs on darwin
  too, with host age identities derived from SSH host keys
  ([decision](decisions/sops-darwin-ssh-host-keys.md)), and gpg-agent/pass
  are class-wide on both OSes. AGENTS.md/README rewritten for dual-OS.

- **Update** — xhigh code-review pass over the de-gating branch fixed seven
  findings: direnv-nom's diff enum was accidentally removed (restored as
  `programs.direnv-nom.diff` — a behavior setting on a universal module);
  override-prone scalars in dnsmasq/homebrew/macos-defaults/neovim/oksh/zsh
  regained `lib.mkDefault` (with the `lib.mkForce` escape hatch documented in
  the [pattern](patterns/host-mounted-modules.md)); nrs/nrb share an `mkNhHelper`;
  and three `okf scaffold` gaps closed — sub-flake re-exports are no longer
  stamped "mounted ungated" (options detected via the backticked comment
  hint, with a generic gated fallback for re-exports), attrset-form
  `programs.<name> = { enable = true; … }` host enables are now detected, and
  same-basename host-specific files get host-qualified doc names instead of
  silently colliding.

- **Update** — nrs/nrt became real executables and gained a sibling: the
  [nh](modules/nh.md) module now ships `writeShellScriptBin` helpers `nrs`
  (nh darwin switch), `nrb` (nh darwin build — no root, safe for agent
  harnesses), and `nrt` (darwin-rebuild check; both `nh darwin test` and
  `darwin-rebuild test` have been removed upstream, so the old nrt alias was
  silently broken). The `environment.shellAliases` block left core.nix —
  aliases only exist in interactive zsh, which is why `nrs` was unavailable
  from non-interactive shells.

- **Update** — removed all `options.kriswill.*` module gating: universal
  features are plain ungated deferred modules in `flake.modules.darwin.*`;
  host-selective features (podman-desktop, claude-account-selector, and the
  apple-container / codebase-memory-mcp sub-flake re-exports) stay under
  `modules/darwin/` behind idiomatic `programs.<name>.*` / `services.<name>.*`
  enables that hosts flip. Hosts became folders —
  `modules/hosts/<hostname>/default.nix` (darwin now, nixos after the
  `nebula-snowglobe` merge) with truly host-specific files beside them
  (`SOC-Kris-Williams/alias-en0.nix`). An intermediate iteration that mounted
  selective features as naked `modules/hosts/*.nix` files was rejected in
  review the same day. The [module option pattern](patterns/host-mounted-modules.md)
  doc was rewritten as the host-mounted modules pattern; decision recorded in
  [remove-option-gating](decisions/remove-option-gating.md). `modules/lib.nix`
  (`kriswill.lib`) and `mkProgramOption` are gone (kanagawa is merged onto
  lib inline by the darwin realiser); the apple-container sub-flake's options
  renamed to `services.apple-container.*`. Deleted the toggle-only `ssh` and
  `neovide` module stubs (and their catalog docs) plus the `lib` plumbing doc;
  `okf scaffold` understands the host-folder layout and stubs host-specific
  sibling files as darwin-module docs. Parity-verified: empty
  `nix store diff-closures` on all three hosts.

## 2026-07-02

- **Update** — xhigh code-review pass over the branch fixed nine findings in
  the okf tooling: viewer URL hashes now round-trip (decoded exactly once,
  `%` escaped on encode, encoded deep links applied without rewriting the
  URL or pushing history entries; malformed sequences select nothing instead
  of throwing), `okf index` refuses to
  regenerate over a malformed root `index.md` frontmatter instead of
  silently stubbing it, panel width + camera view-shift re-clamp on window
  resize, `gitISO` batches all last-commit dates from one `git log` pass
  (viz "sources" phase 917ms → 41ms), the shell's `:root` theme blocks are
  generated from `viz-app/themes.ts` (single source of truth), HTML escaping
  and test fixtures are shared instead of duplicated, and the pages workflow
  comment names the real public URL (<https://kris.net/dotfiles/>).

- **Creation** — viz published as public documentation via GitHub Pages
  (`.github/workflows/pages.yml`): every push rebuilds `viz.html` from the
  bundle with `okf viz` and deploys it as the site's `index.html` at
  <https://kris.net/dotfiles/> — the artifact itself stays gitignored, so
  the page can never go stale relative to the committed knowledge.

- **Update** — viz palette: all 12 concept types now get distinct colors.
  `TYPE_ORDER` grew 8 → 12 curated slots (`--s1..--s12`, append-only so
  existing types keep their hue families); per-theme palettes were
  re-optimized against the dataviz six checks and pass all-pairs
  colorblind separation (Machado protan/deutan ΔE ≥ 15, target 12) on every
  stop's surface — node labels/legend/tooltips carry the documented contrast
  relief. Types beyond the registry no longer fold into one gray: a
  deterministic OKLCH generator (`viz-app/color.ts`, FNV-1a name hash →
  golden-angle hue at theme-tuned lightness/chroma) gives new types stable,
  distinct colors without repainting existing ones.

- **Update** — viz theme slider: four stops (light → medium → dark → black)
  in a footer pinned to the bottom of the sidebar. Each stop is a full CSS
  custom-property set applied inline on `:root` (`viz-app/themes.ts`), so a
  pick overrides the OS scheme and persists in localStorage; untouched, the
  slider follows `prefers-color-scheme`. The scene renders theme-aware by
  background luminance: dark stops keep the glow look (additive edge
  blending, >1.0 bloom-boosted colors, dim-to-black), light stops switch to
  ink-on-paper (normal blending, bloom nearly off, strong node-colored edges,
  de-emphasis fades toward the page instead of black) with per-stop node
  palettes — deep on paper and mid-gray, bright on dark. Overflow types get
  a per-theme `--s-other` (the old hardcoded muted gray vanished on the
  medium background).

- **Update** — viz polish: initial camera now fits the whole graph (aims at
  the layout centroid, backs off to fit the bounding sphere in both FOVs —
  no more small/off-center default view); embedded markdown files render as
  documents (raw md shipped instead of a highlighted source view, links
  resolve file-relative, doc heading styled as the panel title); and the
  detail panel gained a locked sticky header — back link or title crumb plus
  close — visible at any scroll depth on every view.

- **Update** — viz viewer rebuilt on Svelte 5 (runes) via bun-plugin-svelte
  inside the same one-shot `Bun.build` — componentized (Sidebar/Legend/
  Search/ConceptList/Stage/DetailPanel/Tooltip), a rune store with `$effect`
  bridges into the unchanged imperative `GraphScene`, all legacy contracts
  kept (`#data` blob, `window.__okf`, hash routing, panel-width
  localStorage). New: build-phase timings on every run, in-page startup
  marks (`__okf.perf`), `okf viz --perf` (headless-Chrome startup table)
  and `okf viz --check` (svelte-check), plus 52 bun tests. See
  [decision](decisions/viz-svelte-rebuild.md).

- **Update** — Svelte LSP wired into Neovim: `lsp/svelte.lua`
  (`svelteserver --stdio`), enabled in `lua/config/lsp.lua`, and
  `svelte-language-server` added to the [neovim module](modules/neovim.md)'s
  lsp-servers. [nvim/lsp](nvim/lsp.md) and `LANGUAGES.md` updated —
  svelteserver owns `.svelte` buffers (vtsls stays on plain js/ts); svelte
  has no efm formatter so format-on-save is a no-op there. Verified headless:
  attach with correct root + published diagnostics.

- **Creation** — Svelte manual under `docs/svelt/`: `manual.md` hub (cheat
  sheets, tooling, maintenance protocol) plus topic docs `runes.md`,
  `sveltekit.md`, `migration-svelte4-to-5.md`, and an append-only
  `learnings.md` gotcha log. Verified against svelte.dev llms.txt dumps and
  npm registry (svelte 5.56 / kit 2.69). Establishes the `docs/<tool>/`
  manual convention; noted gap: nvim has the svelte treesitter grammar but
  no Svelte LSP config.

- **Update** — viz layout: degree-adaptive forces for real clustering.
  Springs follow the d3-force recipe (strength ∝ 1/min-degree, shorter rest
  for leaf edges, pull biased onto the lower-degree endpoint) and repulsion
  is ForceAtlas2-style degree-weighted, so hubs shove apart and each keeps
  a tight star of satellites instead of one uniform ball.

- **Update** — viz camera: navigating to a node now flies to an exact
  landing (manual pan offsets no longer carry over and clip labels),
  approaches from opposite the node's neighbor centroid so its links fan
  out in view, and the idle auto-rotation is gone — the graph stays put.

- **Update** — Normalized all 30 `<https://…>` autolinks (24 files, mostly
  `Upstream:` lines in `nvim/plugins/`) to explicit inline markdown links.
  The viz markdown renderer also learned pipe tables and autolink syntax,
  and the embedded source-file view now renders `https://` URLs as links.

- **Creation** — New `nvim/` knowledge area covering the whole Neovim
  configuration: core concepts ([architecture](nvim/architecture.md),
  [options](nvim/options.md), [keymaps](nvim/keymaps.md),
  [lsp](nvim/lsp.md), [filetypes](nvim/filetypes.md)) plus a per-plugin
  catalog (23 docs under `nvim/plugins/`). Two decision records added:
  [native vim.pack](decisions/native-vim-pack.md) and
  [efm umbrella formatting](decisions/efm-umbrella-formatting.md).
  `okf scaffold` gained a neovim-plugins pass (stubs
  `nvim/plugins/<name>.md` from `lua/plugins/` specs); type registry gained
  `Neovim Plugin` and `Neovim Config`. Source-side staleness spotted while
  authoring was fixed in a sibling commit: `LANGUAGES.md`'s retired
  home-manager module path, `ftplugin/markdown.lua`'s pre-stow `spellfile`
  path, and duplicate `<leader>n` / `<M-B>` keymap definitions.

- **Update** — `okf viz` rebuilt as a 3D orbit view in the style of
  codebase-memory-mcp's graph-ui: Three.js instanced glow spheres + bloom,
  frozen generation-time layout (`scripts/okf/layout3d.ts`), viewer app in
  `scripts/okf/viz-app/` bundled by bun into the single offline page.

- **Update** — `okf viz` now embeds every referenced source file
  (syntax-highlighted at generation time); `resource:` paths and repo-file
  links in the detail panel open an in-panel code preview with metadata and
  referencing concepts.

- **Update** — `okf` is now a dev-shell command (a `writeShellApplication`
  wrapper in `modules/dev.nix` that resolves the live checkout via git);
  [dev](modules/dev.md) and the [OKF Profile](okf-profile.md) tooling section
  updated to match.

- **Creation** — Bundle created as an OKF v0.1 proof of concept. Seeded with 5
  pattern docs, 6 decision records, 6 playbooks, and 45 scaffolded catalog
  stubs (modules, hosts, packages, sub-flakes). Tooling lives in
  `scripts/okf/` (`scaffold` / `index` / `validate` / `viz`); conventions in
  [okf-profile.md](okf-profile.md).
