# Log

## 2026-07-19

- **Creation** — [rtk-nix-direnv-filters](rtk-nix-direnv-filters.md) /
  [rtk](../packages/rtk.md) / [rtk module](../modules/rtk.md) / `AGENTS.md`:
  added user-global rtk TOML filters stripping `nix run/shell/develop/build/
  flake check` store-fetch noise and `direnv exec` loading noise, sourced
  from real usage data (`rtk discover -a -s 90`). `filter_stderr = true` is
  required for both — nix's fetch/copy lines and direnv's loading/using
  lines are stderr, and a filter can match without it firing, silently.
  Confirmed empirically (`RTK_TOML_DEBUG=1`, real uncached-package runs)
  that custom filters are never consulted by rtk's Claude Code auto-rewrite
  hook, so `AGENTS.md` now documents the six `rtk <cmd>` forms to type by
  hand. `nix eval` (the largest single miss in the scan) was left
  unfiltered — TOML filters strip noise lines, they don't reformat JSON.

- **Update** — [rtk-nix-direnv-filters](rtk-nix-direnv-filters.md):
  `dots-adopt rtk .config/rtk/{config,filters}.toml` captured rtk's config
  into a new `home/rtk` [stow package](../patterns/stow-tree.md), correcting
  the record's earlier "not git-tracked, re-apply per host" claim — the
  filters now propagate via the normal stow restow like any other dotfile.

## 2026-07-18

- **Creation** — [op-service-account-token](op-service-account-token.md) /
  [gh-op](../packages/gh-op.md) / `modules/hosts/nebula/configuration.nix` /
  `modules/hosts/nebula/secrets.yaml`: the gh wrapper's `op read` now prefers
  a 1Password service-account token (`nebula-gh`, read-only on a new
  Automation vault holding only the gh token, 90-day expiry) delivered via
  sops to `/run/secrets/op-sa-token` — ending the per-tty desktop-app
  authorization prompts (10-min idle / 12-h caps, non-configurable). At rest
  it's equivalent to the pre-wrapper plaintext hosts.yml (unencrypted disk),
  but adds audit, one-click revocation, central rotation, and expiry; the
  Private vault and sudo/SSH signing stay biometric-gated.

- **Creation** — [nautilus-dbus-warnings](nautilus-dbus-warnings.md) /
  [gtk-dark](../modules/gtk-dark.md) / [localsearch](../modules/localsearch.md):
  root-caused two of Nautilus's three Hyprland startup warnings. The
  `gtk-application-prefer-dark-theme` deprecation warning traced back to the
  [prior GTK_THEME decision](gtk-theme-env-var-removal.md)'s `busctl`-verified
  portal broadcast actually reading an undeclared, incidental dconf value —
  now declared via `programs.dconf.profiles`. The Tracker
  "name is not activatable" warning was `localsearch` (nixpkgs's rename of
  `tracker-miners`) never being installed/registered. The third warning
  (Mutter `ServiceChannel`) is GNOME Shell-only and has no NixOS-side fix.
  Verified live: `nrs` rebuild + `nautilus .` re-run, warnings 1 and 2 gone.

## 2026-07-16

- **Creation** — [cache-brew-shellenv](cache-brew-shellenv.md) /
  [zsh](../modules/zsh.md) / `home/zsh/.config/zsh/darwin.zsh` / `.gitignore` /
  `docs/shell-startup-performance.md`: profiled why a new tmux pane felt slow
  (timestamped `zsh -x` traces, per-subprocess timing, `STARSHIP_LOG=trace`).
  Cached `brew shellenv`'s output the same way `determinate-nixd`'s
  completion script already was (~30ms/shell saved, warm `zsh -i -c exit`
  ~150-190ms → ~120ms). Removed a stray root-owned `.cache/` in the repo
  root that was making every `git status` here print a permission-denied
  warning, and gitignored `/.cache` against a recurrence. The dominant
  per-pane cost — starship rendering the prompt twice per line, each
  recomputing git status (~130-150ms) — was left alone as a UX tradeoff, not
  a bug; full breakdown in the manual.

## 2026-07-13

- **Update** — [okflight-extraction](okflight-extraction.md) /
  `flake.nix` / [okf](../packages/okf.md) / okf-profile / AGENTS.md /
  [subflake-extraction](../patterns/subflake-extraction.md): the okf input
  moved from `github:kriswill/okflight` (main HEAD) to okflight's FlakeHub
  releases — `https://flakehub.com/f/kriswill/okflight/0`, a semver
  constraint tracking the 0.x series (same style as the `determinate`
  input). Same source revision at swap time (0.2.0 = `2ee7fda`), so no
  closure change; the pin now only advances on published releases via
  `nix flake update okf`.

## 2026-07-12

- **Creation** — [hyprland-unfollow-cachix](hyprland-unfollow-cachix.md)
  / `flake.nix` / [hyprland](../modules/hyprland.md) / `modules/overlays.nix` /
  [dotfiles-stow](../modules/dotfiles-stow.md) / ci.yml: the hyprland input
  stopped following our nixpkgs; nebula consumes `inputs.hyprland.packages`
  directly (overlays dropped) and hyprland.cachix.org is wired as a
  substituter on nebula's daemon, the CI nebula job (`extra-conf`), and the
  flake's nixConfig. Hits are drv-equivalence with upstream's lock (verified
  across a 1,570-commit nixpkgs gap), not a guarantee — `nix flake lock`
  resolves the un-followed dep fresh from unstable HEAD, not upstream's lock.
  hyprpolkitagent de-taints to Hydra-cached nixpkgs drvs, and the
  hyprutils-outpaces-nixpkgs breakage class documented in docs/hyprland.md is
  closed. Stale overlay claims corrected in docs/hyprland.md,
  [cross-os-module-twins](../patterns/cross-os-module-twins.md),
  [nebula](../hosts/nebula.md), and the ci-github-actions accepted-cost bullet.

## 2026-07-11

- **Update** — [ci-github-actions](ci-github-actions.md) /
  `.github/workflows/ci.yml`: gated the long host-closure builds twice
  over. Both triggers now carry a `paths:` allow-list (flake.nix,
  flake.lock, modules/, pkgs/, overlays/, lib/, flakes/, ci.yml itself) —
  docs/knowledge/home/config/scripts changes never alter the closures, so
  they no longer spin runners. And a new `gate` job skips the main-push
  builds when `HEAD^{tree}` equals `HEAD^2^{tree}`: a merge whose tree the
  PR head already carried was built and cache-pushed by that PR's CI run,
  so rebuilding on main is pure rerun. Direct pushes, divergent merges,
  squashes, and `workflow_dispatch` still build.

- **Update** — [ci-github-actions](ci-github-actions.md) /
  [okflight-extraction](okflight-extraction.md) / `.github/workflows/ci.yml`
  / AGENTS.md / README.md / [okf](../packages/okf.md) / okf-profile: stale-claim
  sweep after two input moves. snowglobe-lib now comes from the
  `github:kriswill/snowglobe-lib` fork (`16207cf`) — the Codeberg-5xx retry
  step left ci.yml (its reason to exist is gone; every input is GitHub or
  FlakeHub) and the snowglobe links point at the fork. okflight's
  public-since-2026-07 status corrected everywhere that still described the
  private git+ssh/1Password fetch as current (append-only log entries and
  the extraction record's Decision body stay as history; the record got a
  dated status note instead).

- **Update** — [ci-github-actions](ci-github-actions.md) /
  `flake.nix` / all three workflows: okf turned out to be PUBLIC (flipped
  with the okflight rebrand), so its input became `github:kriswill/okflight`
  and the deploy-key machinery (`OKFLIGHT_DEPLOY_KEY`, ssh-agent,
  known_hosts) left ci.yml, update-flake-lock.yml, and pages.yml — CI now
  holds zero build credentials (FLAKE_UPDATE_PAT for bump PRs is the sole
  secret; retire the deploy key + secret after merge). Added the reusable
  `nix-build-cache.yml` (`workflow_call`): one-job callers give any
  kriswill/* repo Determinate Nix + FlakeHub-cached CI (account-scoped
  OIDC, no per-repo setup); flake-explorer and okflight wired the same day.

- **Update** — [ci-github-actions](ci-github-actions.md) /
  `.github/workflows/ci.yml`: both CI jobs now push the closures they build
  to the private FlakeHub Cache via
  `DeterminateSystems/flakehub-cache-action` (replaces the darwin job's
  `magic-nix-cache-action` GHA backend). Auth is the workflow's OIDC JWT
  (`id-token: write`) — FlakeHub forbids ad-hoc push, so CI is the cache's
  only writer and no cache credential exists; `OKFLIGHT_DEPLOY_KEY` remains
  CI's sole secret. Hosts pull with a one-time `determinate-nixd login`
  (already done + verified on `k`; pending on `mini`, `SOC-Kris-Williams`,
  `nebula` — Determinate Nix writes substituter/netrc/keys itself, zero nix
  config changes).

- **Creation** — [ssh-private-hosts decision](ssh-private-hosts.md):
  private ssh `Host` entries (nephew's homelab `earthlab`, `k-mini`) moved
  out of the public stow config into a dedicated sops file
  (`modules/hosts/k/ssh-hosts.yaml`, key `ssh-private-hosts`) deployed to
  `~/.ssh/config.d/private-hosts` (owner `k`), which the stow config's
  existing `Include ~/.ssh/config.d/*` glob picks up. Dedicated file rather
  than `secrets.yaml`: creating a *new* sops file needs only the public
  recipients (no sudo for the host key), and it can gain `mini`/`SOC`
  recipients later independently of `k`'s own secrets.
  [sops](../modules/sops.md) stub upgraded in the same change (launchd install
  daemon, per-secret `path`, build-time validation gotcha; removed the wrong
  "enable option" scaffold boilerplate);
  [stow-tree](../patterns/stow-tree.md) now lists secret material as the third
  kind of file the tree can't hold; [host k](../hosts/k.md) gained a Secrets
  section.

## 2026-07-10

- **Creation** — [ci-github-actions](ci-github-actions.md) +
  `.github/workflows/{ci,update-flake-lock}.yml`: GitHub Actions now builds
  both deployed closures on every PR — `darwinConfigurations.k.system` on
  the free arm64 macOS runner, nebula's toplevel on ubuntu behind a
  disk-reclaim step — plus a weekly `update-flake-lock@v28` bump PR opened
  with a fine-grained PAT (GITHUB_TOKEN-created events never trigger
  workflows). Load-bearing property: builds never decrypt sops secrets, so
  CI's only credential is the read-only okflight deploy key — no signing
  key, no age key, ever. Chosen over Dependabot's native nix support
  (April 2026) because Dependabot can't bump the private git+ssh okf input.

## 2026-07-05

- **Update** — [python-keyring-op-backend](python-keyring-op-backend.md):
  root-caused the recurring "keystore not working" to a **stale/missing `op` CLI
  session**. Without a cached session each `op item get` does a fresh handshake
  to the 1Password app over `/run/user/1000/1Password-BrowserSupport.sock`, which
  intermittently `connection reset`s; Gajim fetches once per connect with no
  retry, so one failure → offline + password dialog. The user's tell: `op
  signin` by hand fixes it — it caches a session in `~/.config/op/config` that
  separate processes reuse. Fix: `~/.local/bin/gajim-op-launch` (new Linux-only
  stow pkg `home/local-bin`) runs `op signin` to prime, then `exec gajim`; a
  `home/desktop-entries/org.gajim.Gajim.desktop` override calls it. Two launcher
  gotchas: the `Exec` needs the **absolute path** (systemd-`--user`/Noctalia
  PATH lacks `~/.local/bin` → bare name silently no-ops), and Noctalia caches
  desktop entries and won't re-read a changed stow *symlink* (recreate it / it
  rescans; fuzzel rescans every open). Backend also flock-serializes `op`.
  Verified working from both fuzzel and Noctalia. Wrong turns, all corrected:
  (1) lock-state framing (failures happen unlocked); (2) blocking retry in
  `get_password` froze Gajim into "not responding" (GLib main loop); (3)
  `op whoami`/`op account get`/launch-race framings — the real fix is priming a
  reusable session, and my own diagnostic `op` loops caused much of the thrash.

- **Decision** — [python-keyring-op-backend](python-keyring-op-backend.md):
  Gajim's password store is 1Password, not a keyring daemon. New Linux-only
  stow package `home/python-keyring/` vendors a ~60-line python-keyring
  backend shelling out to `op` (items titled
  `python-keyring/<service>/<username>`), selected via `keyringrc.cfg`'s
  `default-keyring`/`keyring-path` — no gnome-keyring, no new nix package,
  secrets stay behind 1Password's lock state. Verified end-to-end
  (CLI round-trip + Gajim saving its XMPP password).

- **Decision** — [gtk-theme-env-var-removal](gtk-theme-env-var-removal.md):
  `gtk-dark.nix` no longer forces `GTK_THEME=Adwaita:dark` — the env var made
  libadwaita apps (Gajim) discard their own stylesheet, collapsing padding.
  The Hyprland portal already broadcasts `prefer-dark` +
  `gtk-theme=adw-gtk3-dark`; the module now just installs `adw-gtk3` so that
  name resolves for GTK3 apps (LibreOffice stays dark).
  [gtk-dark](../modules/gtk-dark.md) and `docs/libreoffice.md` updated.

- **Decision** — [okflight-extraction](okflight-extraction.md):
  okf promoted out of `flakes/okf/` into its own private repository,
  [kriswill/okflight](https://github.com/kriswill/okflight), via
  `git subtree split` (18 commits preserved); the `okf` input URL swapped to
  `github:kriswill/okflight` with `follows` and all consumers untouched —
  the [sub-flake extraction pattern](../patterns/subflake-extraction.md)'s
  promised one-liner, done for real. Dev-shell `okf` is now the nix-built
  package (live hacking moved to a checkout); pages CI checks out okflight
  at the flake.lock-pinned rev via a read-only deploy key; the
  `_okf-scaffold` passes' type-only import is satisfied by a vendored
  `okf-scaffold-api.d.ts`. Private-repo fetches ride `git+ssh` through the
  1Password SSH agent (the signing key re-registered on GitHub as an
  **Authentication** key; no token at rest; nebula auth: pending).

- **Decision** — [okf-scaffold-split](okf-scaffold-split.md): the
  repo scaffolder left `scripts/` for bundle-adjacent
  `knowledge/_okf-scaffold/`, split from one 520-line monolith into a
  `main.ts` entry plus one pass file per scaffolded type (`modules.ts`,
  `hosts.ts`, `packages.ts`, `nvim.ts`) over a shared `lib.ts`. The `_`
  prefix keeps the directory out of walkMd/index-gen, so the bundle stays
  pure markdown — OKF v0.1 conformance only governs `.md` files.
  Parity-verified with a capture-emit harness (100 docs byte-identical old
  vs new); live `okf scaffold`: 0 written, 100 skipped.

## 2026-07-04

- **Update** — [okf-vcs-provider](okf-vcs-provider.md): the git
  provider's batched date pass adds `--diff-merges=c` — files introduced
  during merge conflict resolution (11 in this repo, e.g. `pkgs/cbissue.nix`
  from the `76a05ff` evil merge) had no `lastModified` and fell back to
  `nowISO()`, making `scaffold --force` nondeterministic. Combined diff
  dates them with the merge that created them while clean merges list
  nothing (`first-parent` rejected: it would restamp entire PRs with the
  merge date). Evil-merge fixture test added; two scaffold runs verified
  byte-identical.

- **Decision** — [okf-generalization](okf-generalization.md):
  the okf generalization arc is **complete** — extraction-readiness sweep
  (flake source free of dotfiles assumptions, test fixtures neutralized,
  okf-viz.toml fallback removed, generic README with a no-Nix adoption
  section) verified by a three-way second-repo smoke: a fresh non-Nix
  Python repo through git provider, no-VCS provider, and a standalone
  bun-installed okf copy — init/scaffold/index/validate/viz all green in
  each. Splitting okf to its own repository remains a one-line input swap.

- **Decision** — [okf-scaffold-hook](okf-scaffold-hook.md):
  `okf scaffold` is now a generic driver; the dotfiles metadata pass moved
  out of the flake to `scripts/okf-scaffold.ts` (mechanical port,
  parity-diffed byte-identical), invoked via `okf.toml [scaffold] script`
  with an injected `ScaffoldContext` API (emit/timestamp/leadingComment/…;
  type-only imports, so vendored or store okf both work). Simple repos can
  use declarative `[[scaffold.collect]]` glob+template entries instead;
  `command` is the non-JS escape hatch.

- **Decision** — [okf-facet-classify](okf-facet-classify.md):
  the facet build-side source generalizes from `nix-packages` to
  `[facet.<n>.classify]` with `provider = "nix-optional-attrs"` (existing
  parser, still built-in) or `provider = "command"` (any argv printing a
  JSON name→value map — non-Nix repos can classify by anything). Legacy
  spelling still accepted; plus `key = "basename"|"id"`. Platform map
  verified byte-identical to baseline (5 entries).

- **Update** — [okf-vcs-provider](okf-vcs-provider.md): okf now
  runs **without version control**: `[vcs] provider = "auto"|"git"|"none"`
  (auto = git only at a git toplevel), the `none` provider walks the
  filesystem (junk names + `[vcs] ignore` globs skipped, mtime timestamps,
  no commit links), and the workspace root is discovered config-first —
  nearest `okf.toml` at or above cwd, else the git toplevel. Verified with
  git removed from PATH.

- **Decision** — [okf-vcs-provider](okf-vcs-provider.md): all
  version-control access now sits behind a `VcsProvider` interface
  (`flakes/okf/vcs/`); git is the first provider (batched implementations
  moved verbatim from lib.ts, which is now pure text helpers). Outbound
  revision links are forge-agnostic: `[vcs] commit-url-template`
  (`"{url}/commit/{hash}"` default, GitLab `"{url}/-/commit/{hash}"`),
  remote detection accepts any https/scp/ssh origin, and the viewer fills
  `{hash}` without knowing what GitHub is. `[repo]` remains as a
  deprecated alias of `[vcs]`.

- **Decision** —
  [okf-toml-unified-config](okf-toml-unified-config.md):
  `okf-viz.toml` renamed to **`okf.toml`** — no longer viz settings but the
  okf workspace config, read by every command (legacy name still loads with
  a deprecation warning; pages CI trigger updated in the same commit).
  First step of the okf generalization arc: upcoming sections `[profile]`,
  `[vcs]`, `[scaffold]`, `[index]` and facet `classify` providers will all
  live here.

- **Creation** — [okf-subflake](okf-subflake.md): okf moved
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
  aarch64-linux; no overlay). New [okf](../packages/okf.md) catalog concept;
  `scripts/okf` references swept across AGENTS.md/README/skills/knowledge
  (log history left as-is).

- **Creation** — [viz-config-toml](viz-config-toml.md): every
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

## 2026-07-03

- **Creation** — recorded the
  [vesktop pnpm whitelist decision](vesktop-pnpm-whitelist.md):
  nixpkgs' vesktop deliberately pins the CVE-flagged pnpm-10.29.2 (newer pnpm
  crashes its electron-builder), so nebula tolerates a scoped
  `permittedInsecurePackages` entry for now; the whitelist-free exit (AppImage
  repack à la wowup + `programs.discord.package`) is written down for when
  it's needed.

- **Milestone** — merged the orphan `nebula-snowglobe` branch into one dual-OS
  flake ([decision](nixos-darwin-unification.md)): three darwin
  hosts + the `nebula` NixOS desktop build from a single flake on one
  `nixos-unstable` nixpkgs. `home/` is now shared with per-OS skip lists in
  the stow modules ([decision](stow-os-skip-lists.md)); shared git
  config unified (aliases + difftastic + delta + codeberg helper); ghostty
  split into shared config + generated per-OS `os.conf`; nvim tree
  reconciled on main's (newer) copy. NixOS twins added for nh, git, direnv,
  direnv-nom, ghostty (nebula's direnv had been transitive-only); nebula's
  `packages/` dissolved into `pkgs/` + overlays. sops-nix now runs on darwin
  too, with host age identities derived from SSH host keys
  ([decision](sops-darwin-ssh-host-keys.md)), and gpg-agent/pass
  are class-wide on both OSes. AGENTS.md/README rewritten for dual-OS.

- **Update** — xhigh code-review pass over the de-gating branch fixed seven
  findings: direnv-nom's diff enum was accidentally removed (restored as
  `programs.direnv-nom.diff` — a behavior setting on a universal module);
  override-prone scalars in dnsmasq/homebrew/macos-defaults/neovim/oksh/zsh
  regained `lib.mkDefault` (with the `lib.mkForce` escape hatch documented in
  the [pattern](../patterns/host-mounted-modules.md)); nrs/nrb share an `mkNhHelper`;
  and three `okf scaffold` gaps closed — sub-flake re-exports are no longer
  stamped "mounted ungated" (options detected via the backticked comment
  hint, with a generic gated fallback for re-exports), attrset-form
  `programs.<name> = { enable = true; … }` host enables are now detected, and
  same-basename host-specific files get host-qualified doc names instead of
  silently colliding.

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
  review the same day. The [module option pattern](../patterns/host-mounted-modules.md)
  doc was rewritten as the host-mounted modules pattern; decision recorded in
  [remove-option-gating](remove-option-gating.md). `modules/lib.nix`
  (`kriswill.lib`) and `mkProgramOption` are gone (kanagawa is merged onto
  lib inline by the darwin realiser); the apple-container sub-flake's options
  renamed to `services.apple-container.*`. Deleted the toggle-only `ssh` and
  `neovide` module stubs (and their catalog docs) plus the `lib` plumbing doc;
  `okf scaffold` understands the host-folder layout and stubs host-specific
  sibling files as darwin-module docs. Parity-verified: empty
  `nix store diff-closures` on all three hosts.
