# Log

Root-bundle log: entries here cover bundle-level events only — new bundle
types or directories, root-level concept docs, `docs/` manuals, bundle-wide
sweeps, and workspace tooling conventions. Changes scoped to one bundle log
in that bundle's own `log.md` (e.g. [modules/log.md](modules/log.md)).

## 2026-07-16

- **Update** — logs are now **bundle-scoped**: the root `log.md` (85 entries,
  everything since bundle creation) was split into per-bundle logs —
  [decisions](decisions/log.md) 27, [packages](packages/log.md) 30,
  [modules](modules/log.md) 8, [nvim](nvim/log.md) 2,
  [hosts](hosts/log.md) 1, [patterns](patterns/log.md) 1 — with entry links
  re-based to each file's depth; 16 root-level entries (docs/ manuals,
  root Reference docs, bundle-wide sweeps, workspace tooling, bundle
  creation) remain here. Rationale: isolate type-specific alterations so
  change auditing scopes to a bundle — and this is the spec's own model:
  [OKF SPEC §7](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
  says a `log.md` "MAY appear at any level of the hierarchy to record the
  history of changes to that scope". Convention recorded in
  [okf-profile](okf-profile.md) and the `knowledge-bundle` skill, which now
  warns before root-log writes. `log.md` is a reserved basename at any
  depth, so the new files are invisible to index/validate/viz walks by
  construction.

## 2026-07-09

- **Creation** — New manual `docs/unifi-dream-machine.md`: verified LAN DNS
  architecture (UDM dnsmasq `home.lan` vs the NAS's own mDNS/Bonjour identity
  — macOS SMB mounts ride Bonjour, not DNS), the three headless control paths
  into the UDM (official `integration/v1` API with `X-API-KEY`, legacy
  controller API, SSH read-only), and the OSS ecosystem survey (unifi-mcp,
  DNSControl UniFi provider, terraform forks) with a plan of record for
  agent-driven audit/control.

- **Update** — [unifi-dream-machine](../docs/unifi-dream-machine.md): installed
  and verified sirkirby/unifi-mcp end-to-end against the real UDM (Pro Max,
  Network 10.4.57). Found the NAS's original `home.lan` name is derived from
  the client's raw reported hostname, not a static DNS record —
  `unifi_list_dns_records` returned zero entries. Recorded a gotcha: a
  local-admin password with shell-special characters breaks naive
  `set-env.sh` quoting and surfaces as a 403 on `/api/auth/login`,
  indistinguishable at first glance from a bad-account-type or 2FA-blocked
  login.

- **Update** — [unifi-dream-machine](../docs/unifi-dream-machine.md): documented
  that UNAS Pro 4 / UniFi Drive has its own separate local API on the NAS
  host, unpublished by Ubiquiti and unsupported by sirkirby/unifi-mcp
  (confirmed via the plugin repo's actual file tree — no drive/UNAS package).
  Pulled real endpoint paths and the auth model (session-cookie + CSRF, or
  `X-API-Key`) directly from the reverse-engineered
  [memphi2/ha-unifi-drive](https://github.com/memphi2/ha-unifi-drive) source,
  then confirmed them live against `192.168.0.82`. Noted `GET /api/system` on
  the NAS is unauthenticated and leaks minor device-identity metadata.

- **Update** — [unifi-dream-machine](../docs/unifi-dream-machine.md): added a
  static `nas.home.lan → 192.168.0.82` name via the client's "Local DNS
  Record" field (`unifi_set_client_ip_settings`) after a direct static A
  record was rejected (`StaticDnsOverlapsWithDeviceLocalDns`). Surfaced a
  safety-contract bug in sirkirby/unifi-mcp: `unifi_create_dns_record`
  reported `success: false` on that conflict but had already mutated the
  client's `local_dns_record` field server-side before rejecting — a "failed"
  mutation was not actually a no-op. Documented that a client can carry two
  independent `home.lan` names at once (hostname-derived + Local DNS Record),
  and resolved it by re-running the correct tool explicitly with
  `confirm=true` for a clean record of intent.

## 2026-07-05

- **Update** — okflight's rebrand adopted repo-side: `okf.toml` renamed to
  `okflight.toml` (upstream okf discovers both; new name wins) and the
  scaffold passes moved `knowledge/_okf-scaffold/` →
  `knowledge/_okflight/scripts/`, matching the layout `okf setup` now
  scaffolds everywhere. The vendored type surface refreshed from okflight's
  published template as `scaffold-api.d.ts` (types `ctx.vcs` as a minimal
  `ScaffoldVcs` instead of `unknown`). Current-state docs updated
  ([okf-profile](okf-profile.md), [okf](packages/okf.md), the
  knowledge-bundle skill); decision records keep their historical prose,
  with Where-links repointed at the new paths. The `okf` input advanced
  past the rename (okflight now also on npm as `@kriswill/okflight`).

## 2026-07-04

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

## 2026-07-03

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

## 2026-07-02

- **Creation** — Svelte manual under `docs/svelt/`: `manual.md` hub (cheat
  sheets, tooling, maintenance protocol) plus topic docs `runes.md`,
  `sveltekit.md`, `migration-svelte4-to-5.md`, and an append-only
  `learnings.md` gotcha log. Verified against svelte.dev llms.txt dumps and
  npm registry (svelte 5.56 / kit 2.69). Establishes the `docs/<tool>/`
  manual convention; noted gap: nvim has the svelte treesitter grammar but
  no Svelte LSP config.

- **Update** — Normalized all 30 `<https://…>` autolinks (24 files, mostly
  `Upstream:` lines in `nvim/plugins/`) to explicit inline markdown links.
  The viz markdown renderer also learned pipe tables and autolink syntax,
  and the embedded source-file view now renders `https://` URLs as links.

- **Creation** — Bundle created as an OKF v0.1 proof of concept. Seeded with 5
  pattern docs, 6 decision records, 6 playbooks, and 45 scaffolded catalog
  stubs (modules, hosts, packages, sub-flakes). Tooling lives in
  `scripts/okf/` (`scaffold` / `index` / `validate` / `viz`); conventions in
  [okf-profile.md](okf-profile.md).
