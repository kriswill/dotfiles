# Log

## 2026-07-19

- **Creation** — [rtk](rtk.md): `rustPlatform.buildRustPackage` for
  [rtk-ai/rtk](https://github.com/rtk-ai/rtk) v0.43.0, a CLI proxy that
  filters dev command output to cut LLM token usage. Pinned via
  `fetchFromGitHub` (not a flake input — no fork, all deps from crates.io) with
  `cargoLock.lockFile` reading the crate's own `Cargo.lock` directly.
  `doCheck = false`: its integration tests shell out to git/docker/aws/etc.
  and expect a live tool-populated environment.

## 2026-07-18

- **Update** — [ccglass](ccglass.md): bumped 1.0.0 → 1.1.2 (`fork.patch`
  still applies cleanly; hardcoded `VERSION` literal and both hashes
  updated). Gotcha reconfirmed: bumping the tag without touching `src.hash`
  "succeeds" by silently reusing the cached old source (fixed-output
  derivation) — the first green verify was v1.0.0 code labeled 1.1.2; forcing
  `lib.fakeHash` surfaced the real hashes. All driver checks pass on true
  1.1.2 (version, MCP tools, embedded dashboard assets).

- **Update** — [gh-op](gh-op.md) /
  [op-service-account-token](../decisions/op-service-account-token.md): the
  wrapper's token read moved `op://Private/…` → `op://Automation/…` and now
  prefers `OP_SERVICE_ACCOUNT_TOKEN` from `/run/secrets/op-sa-token` (scoped
  per-read, not exported to gh), falling back to interactive desktop-app
  auth, then hosts.yml. Rotation procedure (90d) documented in the doc.

## 2026-07-11

- **Update** — [gh-config](gh-config.md): `capture`/`diff` now
  normalize the YAML through yq-go (2-space indent, comments/quoting kept)
  instead of copying/comparing verbatim. gh versions disagree on mapping
  indent when rewriting the live file, so verbatim snapshots flip-flopped
  2sp↔4sp across machines (`db80257` and `9873982` accepted opposite
  rewrites). Snapshot is now canonical-format and byte-stable across
  repeated captures; `restore` unchanged. Same day, the zsh `y` yazi
  wrapper (`727b0fb`) learned to recover real dirs from virtual
  `search://<keyword>//<dir>` cwd URLs and to never cd to a non-directory.

- **Creation** — `overlays/ld64-lld.nix` (TEMPORARY): the pinned nixpkgs'
  cctools ld64 1010.6 SIGTRAPs ("Trace/BPT trap: 5") while linking kitty
  0.47.4, vfkit 0.6.3, and starship 1.26.0 on aarch64-darwin — hydra has no
  cache entries for them, so every darwin rebuild fails. The root fix sits
  on staging (NixOS/nixpkgs#536365); master carries per-package
  `-fuse-ld=lld` workarounds (kitty `83cc719d53`, vfkit `559ebc0633`,
  starship `883e799eb2`) that have not reached nixos-unstable (HEAD
  `0bb7ec5`, 2026-07-08). The overlay replicates each workaround
  byte-identically, so kitty and vfkit hash-match hydra's builds and are
  fetched from cache instead of compiled. Inert on Linux
  (`lib.optionalAttrs isDarwin` → empty set; nebula cross-eval verified).
  DELETE the overlay and its `modules/overlays.nix` line at the first
  flake.lock bump that builds all three without it.

## 2026-07-05

- **Update** — [okf](okf.md): the nix package no longer ships the
  test suite (`test/` and `viz-app/*.test.ts` excluded from the runtime
  fileset; a separate full-tree fileset feeds `checks.test`) — bun's test
  scanner follows the `result` symlink `nix build` leaves in the flake
  root, so `bun test` ran a stale store copy of the whole suite alongside
  the local one (24 files instead of 12, doubled counts). The check
  sandbox also gains git, matching the runtime wrapper's PATH: the
  gitProvider tests (evil-merge dating, auto-selection) now run there
  instead of skipIf-skipping, and the one unguarded git-dependent test
  (explicit-git error message) no longer fails git-less.

## 2026-07-04

- **Update** — [okf](okf.md): `okf viz` now bakes a build-time
  size breakdown into the page and shows it in an About modal, opened by
  the sidebar `?` button (now right-aligned in the header and enlarged;
  it replaces the old hover pop-over — the about text lives in the modal,
  dismissed by ✕, Escape, or clicking outside). viz.ts
  measures each section as the exact UTF-8 bytes written into the output
  (concept nodes, edges, embedded files, dir listings, viewer JS/CSS) and
  embeds a `stats` blob in the `#data` JSON. `totalBytes` is
  self-referential — the blob sits inside the file it measures — so the
  page is assembled with a `0` placeholder and the real total solved by
  fixed point on its digit count, then verified against the emitted byte
  length (mismatch aborts the build). First cut compared JS string
  length; the bundle's multi-byte characters made it lie by ~9 KB —
  `Buffer.byteLength` everywhere now, and the CLI summary line reports
  true bytes too. New `AboutModal.svelte`: largest-first table with
  counts/size/share, a derived "page shell & metadata" remainder row so
  rows always sum to the total, and a `Generated` stamp honoring
  `display.date-format`; pre-stats embeds render the modal without the
  table. 7 new tests (296 total).

- **Update** — [okf](okf.md): post-review fixes on the
  generalization PR. Three bugs: collect-tier `output` templates now
  reject `{repo}`/`{description}`/`{description-sentence}` at config load
  (they were expanded before those values existed, silently emitting
  filenames like `widget-{description}.md`); `validate` now flags an empty
  array as an empty required field (arrays are truthy, so the falsy check
  passed `tags: []`); `repoNameFromUrl` drops explicit ports (a manual
  `[vcs] url` with `:8080` corrupted the header name). Plus: git-missing
  vs not-a-repo error messages distinguished again, `[vcs]` non-table
  self-validated, `isObj`/`fieldIn` and the placeholder regex now shared
  single copies, none-provider directory dates memoized, dead exports
  trimmed. Three new regression tests (289 total).

- **Update** — [okf](okf.md): new `okf init [--dir=<d>]`
  bootstraps a fresh workspace (commented starter okf.toml + bundle
  skeleton; never overwrites, no-op when initialized), and `okf help` is
  now config-aware — the bundle dir, viz output path, and the profile-doc
  pointer derive from the workspace's okf.toml via a quiet loader (a
  broken config can never break help). The repo-specific skill pointer
  left the footer.

- **Update** — [okf](okf.md) +
  [okf-profile](../okf-profile.md): validation policy moved from
  code into `okf.toml [profile]` (`required-fields` — `type` always
  enforced, `recommended-fields`, `reserved-files`, `rooted-links`,
  `repo-links`). Defaults reproduce the previous hardcoded
  `RESERVED`/`PROFILE_FIELDS` behavior exactly (this repo's okf.toml sets
  nothing); other bundles can now tune the profile without touching okf.
  New pure-normalizer tests in `flakes/okf/test/config-cli.test.ts`.

- **Update** — [okf](okf.md): all four commands now read their
  config through one shared strict loader (`flakes/okf/config-cli.ts`);
  `bundle.dir` is honored everywhere (previously `validate`/`index`/
  `scaffold` hardcoded `knowledge/` while only `viz` respected the config).
  Behavior change: a malformed config file now fails every command loudly
  instead of being ignored by the non-viz commands. First step of the okf
  generalization arc (decision record lands with the `okf.toml` rename).

- **Update** — [okf](okf.md): `okf viz` detail-panel dates are now
  human-friendly, driven by a new `display.date-format` in `okf-viz.toml`
  (`"iso"` default = as written, `"us"` "Jul 3, 2026", `"international"`
  "3 Jul 2026"; this repo sets `"us"`). Applies to date-shaped frontmatter
  values (full-match only — prose containing a date is untouched) and the
  file/dir "last commit" rows. Formatting reads the literal Y-M-D, never a
  `Date()` timezone conversion, so `2026-07-04T00:00:00-07:00` shows Jul 4
  for every viewer (helper: `flakes/okf/viz-app/dates.ts`).

- **Update** — [podman](podman.md),
  [podman-desktop](../modules/podman-desktop.md): both upgraded from stubs to
  the quality bar. New load-bearing context: the primary workload is
  **minikube's podman driver for work Kubernetes** (minikube itself is not
  nix-managed; k9s rides along per host). podman gains the packaging
  rationale summary (FOD of the official darwin_arm64 zip, dontFixup for
  the adhoc signature, bundled vfkit/gvproxy, applehv-over-libkrun
  backend), podman-desktop the thin-module explanation (`/libexec`
  pathsToLink because `os.Executable` isn't symlink-resolved) and the
  settings.json stow-with-git-filter twist (in-place rewrite, verified
  live symlink, contrasted with
  [snapshot-synced configs](../patterns/snapshot-synced-configs.md)). Both
  cite official sites + the minikube podman-driver docs and link the
  enabling hosts.

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

- **Creation** — [gh-op](gh-op.md) overlay: on Linux, gh is wrapped
  to source `GH_TOKEN` from 1Password at runtime (`op read` of the "GitHub gh
  CLI token" item), and the plain-text oauth token was removed from
  `~/.config/gh/hosts.yml` (`gh auth logout`) — no gh secret at rest on
  nebula's unencrypted disk. One wrapper covers both the CLI and git's
  `!gh auth git-credential` helper; darwin passes through untouched. `op` is
  called by bare name so it resolves to the NixOS setgid wrapper.

- **Creation** — gh's `config.yml` moved from the stow tree (`home/gh/`,
  deleted) to the `config/` snapshot pattern with a new
  [gh-config](gh-config.md) CLI (capture/restore/diff), because gh
  rewrites its config via atomic rename — the same save pattern as
  Helium/Noctalia — which had broken the stow link and silently skipped the
  gh package on every rebuild. First cross-platform snapshot app: the CLI
  ships via the [git](../modules/git.md) twins on both OSes; `hosts.yml` (auth)
  stays untracked. Fresh machines run `gh-config restore` once.

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
  [decision](../decisions/viz-svelte-rebuild.md).

- **Update** — viz layout: degree-adaptive forces for real clustering.
  Springs follow the d3-force recipe (strength ∝ 1/min-degree, shorter rest
  for leaf edges, pull biased onto the lower-degree endpoint) and repulsion
  is ForceAtlas2-style degree-weighted, so hubs shove apart and each keeps
  a tight star of satellites instead of one uniform ball.

- **Update** — viz camera: navigating to a node now flies to an exact
  landing (manual pan offsets no longer carry over and clip labels),
  approaches from opposite the node's neighbor centroid so its links fan
  out in view, and the idle auto-rotation is gone — the graph stays put.

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
  [dev](../modules/dev.md) and the [OKF Profile](../okf-profile.md) tooling section
  updated to match.
