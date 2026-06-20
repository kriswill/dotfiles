# Helium browser manual (nebula)

A working reference for the **Helium** browser as installed and managed on
`nebula` (under Hyprland). Distilled from the upstream project + the Chromium
policy docs, and — where they disagree — **verified against the binary, the live
`/etc/chromium` policy, and the actual profile on this machine**. Maintained for
Claude's use: keep it accurate, prune anything that stops being true, and record
real gotchas in **Learned behaviours & workarounds** at the bottom.

## Version & state on nebula (read this first — it changes everything)

```
$ helium --version
Helium 0.13.4.1 (Chromium 149.0.7827.155)
$ readlink -f $(command -v helium)
/nix/store/2yk5a7k0pwibq15p8b7q9b2jn1vrmfh1-helium-0.13.4.1/bin/helium
$ ls -la /etc/chromium/policies/managed/
lrwxrwxrwx root root helium.json -> /etc/static/chromium/policies/managed/helium.json
$ ls /etc/helium
ls: cannot access '/etc/helium': No such file or directory
$ command -v helium-config
/etc/profiles/per-user/k/bin/helium-config
```

The `managed/helium.json` entry is a **root-owned symlink** (`lrwxrwxrwx` — symlink
perms are always 0777 and irrelevant) that resolves through `/etc/static` to a
`root:root 0444` store file. What matters to Chromium is the dereferenced target:
it must be root-owned and not world-writable, and it is.

- **Helium is an UNBRANDED Chromium fork** — it reads the STOCK Chromium paths:
  profile at `~/.config/net.imput.helium`, managed policy at
  `/etc/chromium/policies/managed/` (NOT `/etc/helium` — that path does not
  exist; the `/etc/chromium/policies` string is embedded verbatim in the real
  ELF, and grep for any `/etc/*helium*` rebrand path comes up EMPTY). This is THE
  fact the whole manual hinges on (verified 2026-06-20).
- **Install:** upstream `programs.helium.enable = true` (the nixpkgs NixOS
  module), set in `modules/nixos/helium/default.nix`. helium 0.13.4.1 / Chromium
  149.0.7827.155 at the pinned flake rev; re-verify after `nix flake update`.
- **Pinned rev / bump:** the `helium` derivation resolves from the
  snowglobe-lib/nixpkgs input (`packages/helium/default.nix:133` in that source
  tree); the pin lives in `flake.lock`. Bump with `nix flake update` (nixpkgs
  follows `snowglobe-lib/nixpkgs`), then re-verify the version line above.
- **Live on the running system (2026-06-20):** the policy file
  (`/etc/chromium/policies/managed/helium.json`, root-owned symlink dated Jun 20
  10:49), `programs.helium.enable` (→ `true`), and `helium-config` on `k`'s PATH
  are all **active on the running system**, and the snapshot is committed
  (`config/helium/`). **Reusable rule:** the policy is read only at Helium startup
  — a freshly-switched policy needs a full Helium restart to take effect. (This
  manual file itself was authored alongside but is not necessarily committed in the
  same commit as the work it describes — see "git + file flake gotcha".)
- **Verified against:** `helium --version`, `readlink -f $(command -v helium)`,
  the live `/etc/chromium/policies/managed/helium.json` (+ `stat`/`namei`
  ownership), `chrome://policy` (**scraped 2026-06-20** on running Helium PID — all
  keys `source=Platform`, `Level=Mandatory`, no "Ignored"; re-verify by reloading
  `chrome://policy`), the live profile
  `~/.config/net.imput.helium/Default/Preferences` + `Local State`, the committed
  snapshot under `config/helium/`, and the repo source files
  (`modules/nixos/helium/{default,policies}.nix`,
  `packages/helium-config.{nix,sh}`, `packages/default.nix`,
  `modules/hosts/nebula/users/k/helium.nix`) — all on **2026-06-20**.

## What it is

Helium is a **privacy-oriented, de-Googled Chromium fork by imput**
(<https://helium.computer>; vendor `imput.net`, hence the reverse-DNS product id
`net.imput.helium`). The nixpkgs `meta` describes it as a "Private, fast, and
honest web browser (Chromium fork by imput)".

- **It is an UNBRANDED fork** — the Chromium ELF inside the package
  (`opt/helium/helium`, ~268 MB) keeps the stock Chromium product strings: the
  managed-policy path is `/etc/chromium/policies/managed`, the crashpad
  annotations report `prod=Chrome_Linux` / `ver=149.0.7827.155` /
  `channel=custom`. There is **no rebrand** of the policy or config paths
  (verified from binary strings, 2026-06-20).
- **uBlock Origin is BUILT IN** as a Chromium *component* extension
  (`blockjmkbacgjkknlgpkjjiijinjdanf`, `location=5` COMPONENT in the live
  profile) — Helium ships and updates it itself. Do NOT force-list it
  (verified 2026-06-20).
- **Helium's de-Googled defaults are a SEPARATE policy source.** At
  `chrome://policy` they appear with `source='Helium defaults'` (the upstream
  *HopProvider*), distinct from our file policies (`source='Platform'`). They
  coexist — e.g. `PasswordManagerEnabled=false` is set by *Helium defaults*, not
  by this repo. Standard Chromium policy keys we set still apply alongside them
  (chrome://policy scraped 2026-06-20; re-verify by reloading the page).
- **Standard Chromium policy keys apply.** Because it's stock-Chromium under the
  rebadge, the entire Chromium Enterprise policy surface is available via the
  managed-policy JSON.

> **Helium reads `/etc/chromium`, NOT `/etc/helium`.** The whole policy mechanism
> below depends on this. `/etc/helium` and `/etc/opt/helium` do not exist on this
> machine and are not referenced anywhere — don't go looking for them.

License/links: upstream <https://helium.computer>; NixOS module
`programs.helium` (<https://search.nixos.org/options?query=programs.helium>).

## How it's installed here (Nix)

Helium is enabled through the **upstream `programs.helium` NixOS module**, driven
by the dendritic layout (see `CLAUDE.md` → Architecture).

```nix
# modules/nixos/helium/default.nix
flake.modules.nixos.helium =
  { ... }:
  {
    programs.helium.enable = true; # upstream programs.helium module
  };
```

- **The `helium` deferredModule MERGE pattern.** Both
  `modules/nixos/helium/default.nix` and `modules/nixos/helium/policies.nix` open
  `flake.modules.nixos.helium = { ... }: { ... }`. `flake.modules.nixos.<name>`
  is a `deferredModule` (the class option comes from
  `inputs.flake-parts.flakeModules.modules`, imported in
  `modules/flake-parts.nix:10`), so the two files **merge into one NixOS module**
  — no `imports` list to maintain.
- **Auto-import via import-tree.** Every `.nix` under `modules/` is auto-imported
  (`flake.nix` → `import-tree ./modules`). The merged `helium` module reaches the
  host through `imports = builtins.attrValues config.flake.modules.nixos;` in
  `modules/hosts/nebula.nix:26`.
- **`enable` was MOVED out of `configuration.nix`.** `programs.helium.enable` now
  lives only in `modules/nixos/helium/default.nix`; `grep -rn helium
  modules/hosts/nebula/configuration.nix` returns nothing. Resolved value:
  `nix eval .#nixosConfigurations.nebula.config.programs.helium.enable` → `true`
  (verified 2026-06-20).
- **The NixOS module surface is tiny.** `programs.helium` exposes exactly
  `enable`, `installForUsers`, `installGlobally`, `package`, `userPackages`.
  There is **NO `commandLineArgs`, `extraOpts`, `extensions`, or `extraArgs`** —
  Chromium command-line flags and force-installed extensions are NOT settable via
  this module. Extensions go through the managed-policy `ExtensionInstallForcelist`
  (below); extra launch flags would require a package wrapper (verified 2026-06-20).
- **`programs.chromium.enable` is `false` — and policies are independent of it.**
  The policy file is written by `environment.etc` (root-owned), which works
  regardless of whether the `chromium` module is on
  (`modules/hosts/nebula/configuration.nix:84` keeps it `false`, yet
  `chrome://policy` shows the keys live). See the next section.

> **Aside — the launch chain (verified 2026-06-20).** `$(command -v helium)` is a
> *compiled* `makeCWrapper` (ELF, not a shell script): two stacked C wrappers
> (`bin/helium` → `bin/.helium-wrapped`) that between them set `QT_PLUGIN_PATH` +
> `XDG_DATA_DIRS` and add `--ozone-platform-hint=auto` (both env-prefix and
> add-flags strings surface together — the exact per-wrapper split isn't separable
> from `strings` alone) → `opt/helium/helium-wrapper` (POSIX sh; sets
> `CHROME_VERSION_EXTRA=custom`, `LD_LIBRARY_PATH`) → `opt/helium/helium`. The
> Wayland/ozone flag is injected by the **package**, not niri/Hyprland, the user,
> or the `.desktop` file (the installed `helium.desktop` is just `Exec=helium %U`).
> Note: the `.desktop` basename is `helium.desktop` while the profile/app id is
> `net.imput.helium` — relevant for window rules / `mimeapps` (`home/mimeapps`
> maps to `helium.desktop`, which matches the installed name).

## Managed policies (declarative)

`modules/nixos/helium/policies.nix` writes the managed-policy JSON declaratively:

```nix
environment.etc."chromium/policies/managed/helium.json".text = builtins.toJSON {
  # … keys below …
};
```

- **`environment.etc`, not `programs.chromium`, and not stow/home-manager.**
  `environment.etc` makes the file **root-owned** (`root:root 0444`, via
  `/etc/static`). Chromium **silently ignores** managed-policy files that are
  world-writable or not root-owned, so a stow-symlinked or home-manager copy
  would NOT work — root ownership is mandatory (verified 2026-06-20).
- **It is LIVE and APPLIED.** The `managed/helium.json` entry is a root-owned
  symlink → `/etc/static/chromium/policies/managed/helium.json` → a `root:root
  0444` `/nix/store/...` file (the dereferenced target — the symlink's own
  `lrwxrwxrwx` mode is irrelevant). At `chrome://policy` on the running Helium all
  keys show `source=Platform`, `scope=Machine`, `level=Mandatory`, empty status (no
  "Ignored"/conflict) (file state verified 2026-06-20; chrome://policy scraped
  2026-06-20).

### Policy keys set

Live JSON content (compact `builtins.toJSON`), grouped by purpose:

| Key | Value | Purpose |
|---|---|---|
| `MetricsReportingEnabled` | `false` | Privacy: no usage/crash metrics upload |
| `BackgroundModeEnabled` | `false` | Privacy: no background process after window close |
| `SafeBrowsingExtendedReportingEnabled` | `false` | Privacy: no extended SafeBrowsing reports |
| `UrlKeyedAnonymizedDataCollectionEnabled` | `false` | Privacy: no URL-keyed data collection |
| `RestoreOnStartup` | `1` | Startup: continue where you left off |
| `ShowHomeButton` | `true` | Startup: show the home button |
| `DefaultSearchProviderEnabled` | `true` | Search: enforce a default provider |
| `DefaultSearchProviderName` | `"DuckDuckGo"` | Search: provider name |
| `DefaultSearchProviderSearchURL` | `https://duckduckgo.com/?q={searchTerms}` | Search: query URL |
| `DefaultSearchProviderSuggestURL` | `https://duckduckgo.com/ac/?q={searchTerms}&type=list` | Search: suggest URL |
| `ExtensionInstallForcelist` | `[Dark Reader, 1Password]` (see below) | Extensions: force-install |

`HomepageLocation` / `HomepageIsNewTabPage` are present but **commented out** in
`policies.nix` — uncomment to pin a homepage.

### Force-installed extensions

`ExtensionInstallForcelist` entries use the `"<id>;<update-url>"` format with the
Chrome Web Store CRX endpoint `https://clients2.google.com/service/update2/crx`:

| Extension | ID | Live version | Install location |
|---|---|---|---|
| Dark Reader | `eimadpbcbfnmbkopoojfekhnkhdbieeh` | 4.9.125 | `7` (EXTERNAL_POLICY_DOWNLOAD) |
| 1Password | `aeblfdkhhhdcdjpifhhbdiojplfjncoa` | 8.12.24.34 | `7` (EXTERNAL_POLICY_DOWNLOAD) |
| uBlock Origin | `blockjmkbacgjkknlgpkjjiijinjdanf` | 1.71.0 (bundled) | `5` (COMPONENT — built in, **NOT** force-listed) |

Both force-listed extensions show `location=7` (`EXTERNAL_POLICY_DOWNLOAD`) in
`Preferences.extensions.settings` — on-disk proof the forcelist policy actually
drove the install (verified 2026-06-20).

> **Force-installed extensions are non-removable in the UI — by design.** That is
> the intended behaviour of `ExtensionInstallForcelist`, not a bug. To remove one,
> delete it from `policies.nix` and rebuild. uBlock Origin is a built-in component
> and **must not** be added to the forcelist.

### How to add / change a key

1. Edit `modules/nixos/helium/policies.nix` (add to the `builtins.toJSON {...}`
   attrset, or to `ExtensionInstallForcelist`). Key names/semantics: Chromium
   Enterprise policy list (Sources).
2. `git add` the change (git+file flake — untracked edits are invisible to Nix).
3. `cd /etc/nixos && sudo nixos-rebuild switch --flake .#nebula`.
4. **Fully restart Helium** (policy is read only at startup; there is no reload
   IPC), then verify at `chrome://policy` → *Reload policies*: the new key shows
   `Source=Platform` / `Level=Mandatory`, empty status (NOT "Ignored").

> **Scraping `chrome://policy`.** The policy table lives entirely inside nested
> shadow DOM (a plain `querySelectorAll('tr')` returns nothing) and the page can
> self-navigate to `chrome://policy/logs`. To read it programmatically,
> deep-traverse `shadowRoot`s matching `[class*=name]/[class*=value]/[class*=source]`,
> re-navigating to `chrome://policy` fresh if you land on `/logs`.

Only the `managed/` (mandatory) subdir is populated; a sibling `recommended/`
(user-overridable defaults) does **not** exist on this machine (live policies
show `Level=Mandatory`) (verified 2026-06-20).

## What is NOT policy-manageable

**Per-extension keyboard shortcuts.** There is **no Chromium policy key** for
per-extension command bindings (absent from the full policy list at
`chrome://policy`; scraped 2026-06-20, re-verify by reloading the page). They live
ONLY in mutable profile state at
`~/.config/net.imput.helium/Default/Preferences`:

- `extensions.commands` — the **authoritative active-binding map**, keyed
  `"linux:<accel>"` → `{command_name, extension, global}`.
- `extensions.settings.<id>.commands.*` — per-extension command records (a
  `suggested_key` with `was_assigned=false` is just the extension's *manifest
  default*, NOT an active binding).

Set them by hand at `helium://extensions/shortcuts`. Current observed bindings —
only `extensions.commands` is authoritative:

| Extension | Command | Accelerator | Status |
|---|---|---|---|
| Dark Reader | `toggle` | `Alt+Shift+D` | **bound** (in `extensions.commands`) |
| 1Password | `_execute_action` | `Ctrl+Shift+X` | **bound** (in `extensions.commands`) |
| Dark Reader | `addSite` | `Alt+Shift+A` | manifest default, `was_assigned=false` — **NOT bound** |
| 1Password | `lock` | `Ctrl+Shift+L` | manifest default, `was_assigned=false` — **NOT bound** |
| uBlock Origin | all commands | (empty) | **unbound** (`suggested_key=""`) |

> **Correction to earlier notes:** only TWO accelerators are actually bound
> (`Alt+Shift+D`, `Ctrl+Shift+X`). The `addSite=Alt+Shift+A` / `lock=Ctrl+Shift+L`
> values seen under `extensions.settings.<id>.commands` are echoed *manifest
> defaults* with `was_assigned=false`, absent from `extensions.commands` — do not
> read them as live bindings (verified 2026-06-20).

These bindings **ride along in the snapshot** (`helium-config capture` keeps
`extensions.commands` and `extensions.settings.<id>.commands`; the capture jq
filter only strips `extensions.last_chrome_version`). A `restore` re-establishes
them only because it overwrites `Preferences` wholesale — there is no policy-based
enforcement, so a fresh profile starts with each extension's manifest defaults.

## The profile (where settings live)

| Path | Size | Holds |
|---|---|---|
| `~/.config/net.imput.helium` | 318M | config **+ state + most caches** (default profile) |
| `~/.cache/net.imput.helium` | 1.4G | ONLY the HTTP/Code disk cache (`Default/Cache`, `Default/Code Cache`) |

- **Helium uses the DEFAULT profile.** The running browser (PID 22128, live during
  verification) has cmdline exactly `…/opt/helium/helium --ozone-platform-hint=auto`
  — no `--user-data-dir` / `--disk-cache-dir` override — so it reads
  `~/.config/net.imput.helium` and holds its open fds there. This running cmdline
  is the strongest single confirmation of the "default profile, no relocation
  flags" claim (verified 2026-06-20).
- **Chromium IGNORES the XDG split.** `ShaderCache`, `GraphiteDawnCache`,
  `GrShaderCache`, `Default/GPUCache`, `Default/IndexedDB`, `Default/Service
  Worker`, `Default/Local Storage`, `Default/Session Storage`,
  `GPUPersistentCache` all live under **`$XDG_CONFIG_HOME/net.imput.helium`**, NOT
  under `$XDG_CACHE_HOME`. Only the HTTP/Code disk cache goes to `~/.cache`.
  **So `~/.config/net.imput.helium` is NOT "pure settings"** — it is 318M of
  mixed config + state + GPU caches. Nothing Helium-related lives under
  `~/.local/share` or `~/.local/state` (verified 2026-06-20).
- **Only two relocation knobs exist:** `--user-data-dir` (whole profile) and
  `--disk-cache-dir` (HTTP cache only). There is NO knob to push state to
  `~/.local/state` or data to `~/.local/share`. Since `programs.helium` has no
  `commandLineArgs`, relocating the profile needs a `makeWrapper`/`symlinkJoin`
  package wrapper. NixOS does **not** read `~/.config/helium-flags.conf` (an Arch
  chromium-wrapper convention) — no such file is consulted here.

File categories in `Default/` — the settings/state/secrets split that drives the
snapshot allowlist:

| Category | Files (examples) | In repo snapshot? |
|---|---|---|
| Settings (snapshotted) | `Default/Preferences`, `Local State`, `Default/Bookmarks(+.bak)` | **Yes** (allowlist) |
| Secrets / bulk state | `Login Data`, `Login Data For Account`, `Cookies`, `Web Data`, `Affiliation Database`, `History`, `Top Sites`, `Favicons` | **Never** |
| Host-bound | `Default/Secure Preferences` (super_mac HMAC over machine id) | **Excluded** |

### The stale `~/.config/chromium` profile (out of scope)

`~/.config/chromium` (60M) + `~/.cache/chromium` (146M) is a **separate,
USER-created ungoogled-chromium "Work" profile**, abandoned ~2026-06-06 — NOT
Helium, NOT automation:

- `Last Version` = `148.0.7778.178` (vs Helium's Chromium 149.0.7827.155);
  `info_cache` profile name = `Work`; mtimes frozen at 2026-06-06 16:25.
- It is **ungoogled-chromium**: the domain-substitution fingerprint
  `chrome.9oo91e.qjz9zk` appears in `Default/Top Sites` (stock Chromium wouldn't
  rewrite the domain).
- Real human history (`mail.google.com`, `claude.ai`, `coinbase.com`,
  `fandango.com`, `1password.com`, `nix.dev`). Its only recently-touched file is
  `NativeMessagingHosts/com.1password.1password.json` (rewritten by the 1Password
  integration, not browsing).
- **Left untouched, out of scope.** Helium never opens it (0 fds there). The
  `chrome-devtools-mcp` automation profile lives under
  `~/.cache/chrome-devtools-mcp/`, never `~/.config/chromium`; no Playwright /
  Puppeteer caches exist on this machine (verified 2026-06-20).

## Tracking user settings in the dotfiles repo (snapshot, not stow)

Helium user settings are version-controlled via a **snapshot CLI**, not stow —
the same pattern as Noctalia (see `docs/noctalia.md`, commit `d1bdd0e`).

> **WHY NOT STOW (two independent reasons).**
> 1. **Atomic-rename trap.** Chromium saves `Preferences`/`Bookmarks`/`Local
>    State` via a same-dir temp + `rename()`, which **replaces a stow symlink
>    with a real file on the first save**, silently breaking tracking. (The
>    `restore` verb itself uses `mv -f` for exactly this reason.)
> 2. **`home/` auto-restow clobber.** `modules/nixos/dotfiles-stow.nix` runs
>    `stow --no-folding --restow` for EVERY directory under
>    `/home/k/src/dotfiles/home` on every `nixos-rebuild switch` (auto-discovered),
>    so a `home/helium` package would symlink the repo copy **over** the live
>    profile and clobber it. Same trap that caused the niri black-wallpaper
>    incident.

So `config/helium/` lives **OUTSIDE both `home/` and `modules/`** — stow never
symlinks it (it scans only `home/`) and import-tree never evaluates it (it scans
only `./modules`). Cross-ref `config/README.md`.

### `helium-config` CLI

| Command | Effect |
|---|---|
| `helium-config capture` | live profile → repo snapshot (`config/helium/...`); allowlist only, jq-filtered, `0644`; prints a `git diff` hint, does NOT commit |
| `helium-config restore` | snapshot → live, atomic (`mv -f`), re-hardened to `0600`, backs up the live file to `.bak`; **refuses while Helium runs unless `FORCE=1`** (detected via `pgrep -x helium`) |
| `helium-config diff` | snapshot vs jq-filtered live; exit 1 on drift, prints `(in sync)` (exit 0) when clean |

```sh
helium-config capture                            # after settings edits
git -C ~/src/dotfiles diff -- config/helium      # review
git -C ~/src/dotfiles commit -- config/helium
# fresh machine / undo (quit Helium first):
helium-config restore
```

Env overrides: `HELIUM_PROFILE` (default `$HOME/.config/net.imput.helium`),
`DOTFILES` (default `$HOME/src/dotfiles`). Snapshot dir is `$DOTFILES/config/helium`.

- **Allowlist only (4 entries).** `Default/Bookmarks|raw`,
  `Default/Bookmarks.bak|raw`, `Default/Preferences|prefs`, `Local State|localstate`.
  Absent files are skipped (`skip (absent): <rel>`). **Secrets/bulk state never
  enter the repo** — no `Login Data`, `Cookies`, `History`, `Web Data`, IndexedDB.
  `Default/Secure Preferences` is **excluded** (host-bound super_mac HMAC).
  The committed snapshot is verified credential-free:
  `password_manager.password_hash_data_list` is ABSENT and
  `os_crypt.encrypted_key` is absent (`os_crypt` holds only desktop-portal state
  `{portal: {prev_desktop: Hyprland, prev_init_success: false}}` — no key
  material) (verified 2026-06-20).
- **jq churn filters + key-sort (`-S`)** for stable diffs:
  - `Preferences`: `del(.profile.exit_type, .profile.last_engagement_time,
    .profile.last_active_time, .browser.window_placement, .session, .sessions,
    .extensions.last_chrome_version, .ntp.num_personal_suggestions)`
  - `Local State`: `del(.user_experience_metrics, .variations_crash_streak,
    .variations_failed_to_fetch_seed_streak, .variations_seed_date,
    .session_id_generator_last_value, .uninstall_metrics, .legacy)`
- **Perms: `0644` in the tree, `0600` on restore.** git records only the exec
  bit, so a checked-out snapshot is `0644`; restore re-hardens to `0600` (the
  perms Chromium-profile files must carry).
- **Current snapshot state:** `config/helium/Default/Preferences` (~105KB
  pretty-printed) + `config/helium/Local State` are committed. NO
  `Default/Bookmarks` yet — Chromium only writes it once a bookmark exists, so
  the Bookmarks allowlist entries are pre-provisioned but inert. `diff` currently
  reports drift (the live profile evolved since the snapshot) — re-`capture` to
  re-sync (verified 2026-06-20).
- **No reload IPC (unlike noctalia).** Helium reads these files only at startup,
  so `restore` is meant for a quit browser / fresh machine; the `FORCE=1` path
  during a running browser is last-writer-wins.
- **`restore` detects a running browser via `pgrep -x helium`** (exact
  process-name match; `procps` is in `runtimeInputs`). All ~40 Helium child procs
  report `comm=helium`, so the guard fires reliably while the browser runs (tested
  2026-06-20). A renamed binary would defeat it — keep the process name `helium`.
- **`diff`'s exit-1-on-drift is incidental, not deliberate.** Under `set -euo
  pipefail` the branch exits 1 only because its final statement `[ "$rc" = 0 ] &&
  echo "(in sync)"` evaluates false when `rc=1`; there is no explicit `exit "$rc"`.
  **Do not append commands after that test** in `helium-config.sh` or you'll
  silently break the documented exit code (or harden it with an explicit
  `exit "$rc"`).

### Extending the snapshot

Mirror of `config/README.md` → *How to maintain it* (keep the two in sync):

1. **Track a new file** — add a `"relpath|transform"` entry to the `files=(…)`
   array in `packages/helium-config.sh` (transforms: `raw` = byte-copy, `prefs` /
   `localstate` = the per-file jq churn filters). Then `git add`, rebuild, and
   `helium-config capture`.
2. **Silence a noisy diff** — a volatile key is leaking through; add it to the
   relevant `del(…)` filter (`prefs_filter` for `Preferences`, the `Local State`
   filter for that file) in `packages/helium-config.sh`, then rebuild +
   re-`capture`.
3. Cross-ref `config/README.md`'s numbered procedure so the manual and the README
   don't drift.

### git + file flake gotcha

These are `git+file://` flakes — **newly created files are invisible to Nix
evaluation until `git add`-ed**. New `packages/*.nix`, `packages/*.sh`, and
`modules/**` files must be staged before `nixos-rebuild` (this is the same class
of bug that previously left `programs.helium.enable=false`). `packages/helium-config.{nix,sh}`
and `modules/hosts/nebula/users/k/helium.nix` are currently tracked (committed in
`3092346`). Mirrored in `config/README.md`. Note: this manual (`docs/helium.md`)
is itself prose and `import-tree`-invisible, and was authored *after* the
`ab15ed6`/`3092346` work commits — so the manual may briefly be untracked while
the work it documents is already committed.

## nebula wiring

| File | Role |
|---|---|
| `modules/nixos/helium/default.nix` | `programs.helium.enable = true` (merges into the `helium` deferredModule) |
| `modules/nixos/helium/policies.nix` | writes `/etc/chromium/policies/managed/helium.json` via `environment.etc` (merges into the same module) |
| `packages/helium-config.nix` | `writeShellApplication` (`name = "helium-config"`, `runtimeInputs = [ coreutils jq diffutils procps ]`, `text = builtins.readFile ./helium-config.sh`) |
| `packages/helium-config.sh` | the actual bash — **extracted out of Nix** so it lints/runs standalone (no Nix interpolation) |
| `packages/default.nix` | registers `helium-config = pkgs.callPackage ./helium-config.nix { };` |
| `modules/hosts/nebula/users/k/helium.nix` | puts `helium-config` on `k`'s PATH (`users.users.k.packages = [ pkgs.helium-config ]`, wrapped as `configurations.nixos.nebula.module`) |
| `config/helium/` | the committed snapshot (outside `home/` and `modules/`) |
| `config/README.md` | documents the snapshot mechanism (shared with noctalia) |

The tooling is **built and active** for `k`:
`command -v helium-config` → `/etc/profiles/per-user/k/bin/helium-config`, and the
installed binary body matches the committed `helium-config.sh` (verified 2026-06-20).

## Changelog

- **2026-06-20 — managed policy baseline** (`ab15ed6`): the declarative privacy
  baseline + DuckDuckGo search + Dark Reader/1Password forcelist, committed and
  applied via `nixos-rebuild switch`. Details: *Managed policies (declarative)*.
- **2026-06-20 — snapshot tooling** (`3092346`): `helium-config`
  (capture/restore/diff) on `k`'s PATH; initial capture committed
  `config/helium/Default/Preferences` + `Local State`. Details: *Tracking user
  settings in the dotfiles repo*.

## Learned behaviours & workarounds

- **Helium reads `/etc/chromium`, not `/etc/helium` (2026-06-20).** Unbranded
  Chromium fork; the policy path is stock. `/etc/helium` / `/etc/opt/helium`
  don't exist (proven from binary strings). Don't waste time looking for a
  rebrand path.
- **The policy file MUST be root-owned (2026-06-20).** Chromium silently ignores
  managed-policy files that are world-writable or not root-owned. `environment.etc`
  gives `root:root 0444` for free; a stow/home-manager-symlinked policy would NOT
  work — which is also why this is `environment.etc`, not `programs.chromium`
  (left `false`).
- **`cat $(which helium)` prints an ELF, not a script (2026-06-20).** The
  user-facing wrapper is a compiled `makeCWrapper`. There are TWO stacked C
  wrappers (`bin/helium` → `bin/.helium-wrapped`) before the POSIX-sh
  `helium-wrapper`. The inner C wrapper injects `--ozone-platform-hint=auto` — do
  not attribute the Wayland flag to niri/Hyprland, the `.desktop`, or the user.
- **No `programs.helium` knob for flags/extensions (2026-06-20).** The module is
  `enable`/`installForUsers`/`installGlobally`/`package`/`userPackages` only.
  Extensions → `ExtensionInstallForcelist`; extra flags / profile relocation →
  package wrapper. There is no `helium-flags.conf` on NixOS.
- **Force-installed extensions are non-removable in the UI (2026-06-20).** By
  design (`location=7` EXTERNAL_POLICY_DOWNLOAD). Remove via `policies.nix` +
  rebuild. uBlock Origin is a built-in COMPONENT (`location=5`) — never force-list it.
- **Per-extension shortcuts are NOT policy-manageable (2026-06-20).** No Chromium
  policy key. Authoritative source is `Preferences.extensions.commands`
  (`"linux:<accel>"`); a `suggested_key` with `was_assigned=false` is a manifest
  default, not a live binding. Set at `helium://extensions/shortcuts`; they ride
  along in the snapshot but aren't enforced.
- **XDG non-compliance is a trap (2026-06-20).** `~/.config/net.imput.helium` is
  config + state + GPU caches (318M), NOT just settings — IndexedDB, Service
  Worker, Local/Session Storage, shader caches all live there. Only the 1.4G
  HTTP/Code disk cache lives in `~/.cache`. Never assume "config = safe to commit"
  — that's exactly why the snapshot uses a strict allowlist.
- **Stow/atomic-rename incompatibility + `home/` auto-restow clobber (2026-06-20).**
  Chromium's `rename()` saves destroy a per-file stow symlink on first write, and
  `dotfiles-stow.nix` restows every `home/` package each rebuild — so the snapshot
  must live in `config/` (sibling of `home/`), synced explicitly by `helium-config`.
- **git+file flakes ignore untracked files (2026-06-20).** `git add` new
  `packages/*.{nix,sh}` / `modules/**` before `nixos-rebuild`, or Nix won't see
  them (this once left `programs.helium.enable=false`).
- **Snapshot JSON is jq pretty-printed + key-sorted (2026-06-20).** The repo copy
  (~105KB) is LARGER than the compact live `Preferences` (~71KB) — reformatting
  plus `jq -S`, not data inflation.
- **Audit the snapshot by jq value, not `grep` (2026-06-20).** `grep -E
  'password|cookie|token|secret'` over `config/helium` hits only benign extension
  manifest metadata and Chromium pref *keys*. The real secret check is
  `os_crypt.encrypted_key` (absent) and `password_manager.password_hash_data_list`
  (absent) — `os_crypt` here is just desktop-portal state.

## Sources

- Chromium Enterprise policy list — <https://chromeenterprise.google/policies/>
  (policy key names/semantics: `ExtensionInstallForcelist`, `RestoreOnStartup`,
  `DefaultSearchProvider*`, the privacy/metrics keys; the
  `managed/`-vs-`recommended/` distinction).
- Helium upstream project — <https://helium.computer> (privacy-focused,
  de-Googled Chromium fork by imput; built-in uBlock Origin; the de-Googled
  *HopProvider* / "Helium defaults" policy source).
- NixOS `programs.helium` module reference —
  <https://search.nixos.org/options?query=programs.helium> (the five options:
  `enable`/`installForUsers`/`installGlobally`/`package`/`userPackages` — note,
  contradicting any assumption otherwise, there is NO `commandLineArgs`/`extensions`).
- Chrome Web Store CRX update endpoint —
  <https://clients2.google.com/service/update2/crx> (the `update_url` used by
  `ExtensionInstallForcelist`).
- Pinned `helium` flake input — resolves via the snowglobe-lib/nixpkgs input
  (`packages/helium/default.nix:133` in that source tree); pin recorded in
  `flake.lock` (bump via `nix flake update`).
- Registered in the **`CLAUDE.md` manuals table** (the discoverability index for
  all `docs/` manuals — this manual has a row there).
- Sibling manuals & repo files — `docs/noctalia.md` (the shared snapshot-not-stow
  pattern, commit `d1bdd0e`), `config/README.md`,
  `modules/nixos/helium/{default,policies}.nix`,
  `packages/helium-config.{nix,sh}`, `packages/default.nix`,
  `modules/hosts/nebula/users/k/helium.nix`,
  `modules/nixos/dotfiles-stow.nix` (the `home/` auto-restow scope).
- **Machine-verified on nebula, 2026-06-20:** `helium --version`;
  `readlink -f $(command -v helium)`; `ls -la`/`stat`/`namei`
  `/etc/chromium/policies/managed/helium.json`; `cat` of that JSON;
  `ls /etc/helium` (absent); `command -v helium-config`;
  `nix eval .#nixosConfigurations.nebula.config.programs.helium.enable` (→ `true`)
  and `…options.programs.helium` attr names; `chrome://policy` (shadow-DOM scrape
  of the running Helium — all our keys `source=Platform`/`Mandatory`,
  *Helium defaults* distinct); `jq` over the live
  `~/.config/net.imput.helium/Default/Preferences` + `Local State`
  (`extensions.commands`, `extensions.settings.<id>.location`); `du -sh` of the
  profile/cache and the stale `~/.config/chromium`; and `jq` over the committed
  `config/helium/` snapshot (no `os_crypt.encrypted_key`, no
  `password_hash_data_list`).
