# Log

## 2026-07-22

- **Update** — [yazi](yazi.md): stub upgraded; the markdown-preview plugin
  `faster-piper` moved from a flake-input store symlink to a vendored fork
  in the stow tree with interruption-safe, atomic cache generation (see
  [vendor-faster-piper-fork](../decisions/vendor-faster-piper-fork.md));
  the activation script now links only `git` + `types.yazi` + the flavor.

## 2026-07-20

- **Update** — [rtk](rtk.md) /
  [claude-account-selector](claude-account-selector.md): the darwin rtk twin
  now bridges rtk's macOS config path — rtk reads user-global
  config/filters from `dirs::config_dir()` = `~/Library/Application
  Support/rtk` (XDG ignored on macOS), so the stowed `~/.config/rtk/`
  files were silently unread on darwin; a `postActivation` script (order
  1600) symlinks `{config,filters}.toml` across, per-file because rtk
  keeps mutable state (`history.db`) in the same dir. Also registered
  rtk's Claude Code hook on `k` — `rtk init -g --auto-patch` once per
  claude-account-selector profile (`CLAUDE_CONFIG_DIR=~/.claude-me` and
  `~/.claude-work`), patching each profile's `settings.json` with the
  `PreToolUse`/`Bash` → `rtk hook claude` rewrite hook and dropping
  `RTK.md` + the `@RTK.md` CLAUDE.md reference.

## 2026-07-19

- **Creation** — [gnome-keyring](gnome-keyring.md): `services.gnome.gnome-keyring.enable
  = true;`, added because atuin-desktop's Hub-connect "Accept" button was
  permanently stuck — its `confirm()` handler has no try/catch around the
  keyring-save Tauri call, so with no Secret Service running it fails and
  the dialog can never dismiss (root-caused by reading `DesktopConnect.tsx`
  and `auth.ts` upstream). Traced with `busctl --user status
  org.freedesktop.secrets` → no owner, no gnome-keyring/kwallet process.
  First attempt at this module had **zero effect**: `mkForce false` was
  already set in [sudo-1password.nix](../hosts/nebula.md) from the earlier
  1Password sudo-ssh-agent work, which always wins over a plain `= true`.
  That force went further than its own comment's stated intent
  ("keyring secrets/pkcs11 stay enabled") — the actual SSH_AUTH_SOCK
  conflict is fully isolated one line above by
  `services.gnome.gcr-ssh-agent.enable = false;` alone — so the `mkForce`
  was removed rather than fought with a second `mkForce`. Verified both
  ways post-fix: `gnome-keyring.enable` → `true`, `gcr-ssh-agent.enable`
  stays `false`, full nebula closure builds.
- **Update** — [zsh](zsh.md): atuin CLI sync enabled and verified working
  (`auto_sync = true`, `docs/atuin.md` Sync section). Two findings worth
  keeping straight: (1) atuin 18.x defaults to Hub-native sync — `atuin
  login -u <user>` saves a `hub_session` row in `meta.db`, never a
  `~/.local/share/atuin/session` file (that's a legacy-login-only artifact,
  doesn't exist here) — so `atuin account link` correctly errors "No CLI
  session found" on this account type, it's not applicable, not broken; (2)
  `atuin login`'s password/key prompts open `/dev/tty` directly and panic
  (ENXIO) when run through Claude Code's `!` relay — needs a real terminal.
  Confirmed sync works by running `atuin sync` directly (uploaded records,
  "Sync complete!"), not by trusting `atuin status`'s `Last sync` field,
  which didn't visibly update in testing.
- **Creation** — [atuin-desktop](atuin-desktop.md): `pkgs.atuin-desktop` (Tauri
  GUI runbook editor, same upstream project as the [atuin](zsh.md) CLI)
  installed nebula-only. Single-file module — the derivation ships its own
  `.desktop` entry/icons, so `environment.systemPackages` is the whole thing,
  no `desktop-entries` stow work needed. Universal within the nixos class
  (single host today); retrofit a `programs.atuin-desktop.enable` gate if a
  second, non-desktop NixOS host appears. Playbook: `docs/atuin.md`. First
  real-machine launch hit "Failed to create welcome workspace — Permission
  denied (os error 13)"; traced to upstream source (`workspaces.rs`,
  `copy_welcome_workspace`) — it copies its bundled example workspace out of
  the Nix store with `fs::copy` (preserves the store's `444` perms) then
  immediately rewrites the copy, EACCES every time on any Nix install.
  Verified live: the copied `atuin.toml` really is `444`. No nix-side fix
  possible; documented as a known upstream bug with a workaround ("Create
  new workspace" instead of the auto-offered one).
- **Update** — [zsh](zsh.md): the CLI's stow-managed `home/atuin/.config/atuin/config.toml`
  never actually got symlinked on nebula's first `nrs` after this module
  landed — something (most likely atuin-desktop's own "is the CLI
  installed?" first-run check) ran the `atuin` binary and auto-wrote a full
  default config to that path *before* the rebuild's stow activation ran,
  so stow found a real file already there and silently skipped the whole
  package. `history_filter`/`auto_sync`/`update_check` were dead the whole
  time. Fixed by hand (`rm` the stray file, `stow --restow atuin`);
  full gotcha in `docs/atuin.md` Learned behaviours.

- **Creation** — [rtk](rtk.md): cross-OS twin (`modules/darwin/rtk.nix` /
  `modules/nixos/rtk.nix`) mounting the [rtk package](../packages/rtk.md) onto
  `environment.systemPackages`. Registering `pkgs.rtk` under
  `perSystem.packages` alone (as first done) only creates a flake output
  (`nix build .#rtk`) — it never reaches a host's own `pkgs`, so `nrs`/nixos-
  rebuild installed nothing until the [overlay](overlays.md) plus these
  module twins were added (see the [add-package playbook](../playbooks/add-package.md)
  step 3, easy to skip for a package that also happens to build standalone).

- **Update** — [rtk](rtk.md): cross-linked the
  [nix/direnv custom filters decision](../decisions/rtk-nix-direnv-filters.md).

## 2026-07-18

- **Update** — [zsh](zsh.md): swapped `hstr` for `atuin` as the Ctrl-R
  history picker (both class twins' package lists, `home/zsh/`'s
  `integrations.zsh`/`.zshrc` comments). `atuin init zsh` also claims
  Up-arrow, unlike hstr. New stow package `home/atuin/.config/atuin/config.toml`
  (mirrors [starship](../modules/zsh.md)'s pattern — a plain config file, no
  nix module needed since it embeds no store paths) sets `auto_sync = false`
  / `update_check = false`: no sync account is configured on any host, so
  both would otherwise be dead network calls on every shell start. Playbook:
  `docs/atuin.md`.
- **Update** — [gtk-dark](gtk-dark.md) now declares
  `programs.dconf.profiles.user.databases` with
  `org/gnome/desktop/interface.color-scheme = "prefer-dark"`, instead of
  relying on whatever value happened to already be sitting in nebula's live
  dconf database. Trigger: Nautilus warned
  `gtk-application-prefer-dark-theme … is unsupported` — that legacy key
  (removed from `home/gtk`'s `gtk-4.0/settings.ini`, kept in `gtk-3.0`) was
  the only thing actually giving libadwaita apps a dark theme, since the
  portal had no declared `color-scheme` to broadcast.
- **Creation** — [localsearch](localsearch.md): enables
  `services.gnome.localsearch` (nixpkgs's rename of `tracker-miners`) so
  `org.freedesktop.Tracker3.Miner.Files` is D-Bus-activatable — Nautilus
  was warning "the name is not activatable" for it. Both fixes and the
  still-unfixable third Nautilus warning (Mutter `ServiceChannel`, GNOME
  Shell-only) are covered in the
  [decision record](../decisions/nautilus-dbus-warnings.md).

## 2026-07-16

- **Creation** — [gui-path](gui-path.md): GUI apps get the nix PATH.
  Two-pronged: `launchd.user.envVariables.PATH` (user-domain `launchctl
  setenv` at activation — Dock/Finder-launched apps otherwise inherit the
  bare `/usr/bin:/bin:/usr/sbin:/sbin`) plus a `home/zsh/.zshrc` shim for
  apps that parse `~/.zshrc` to recover PATH instead of trusting their
  environment (Claude Code desktop's documented probe). The shim is inert
  for real shells: [zsh](zsh.md)'s ZDOTDIR points zsh at
  `~/.config/zsh/.zshrc` on both OSes, which is precisely why the probe
  found nothing before. Trigger: Claude Code desktop's CI monitoring
  reporting "gh not installed" while gh (nix profile only) worked in every
  terminal.

## 2026-07-15

- **Creation** — [oled-resume-bump](oled-resume-bump.md) /
  `modules/hosts/nebula/oled-resume-bump.nix` / docs/hyprland.md: the DP-3
  OLED (PG34WCDM) sometimes stays black after resume while Hyprland reports
  the output live; a per-output DPMS bounce wakes it, so
  `powerManagement.resumeCommands` now runs one on every resume
  (root → `runuser -u k`, hyprctl from `config.programs.hyprland.package`).
  Same day, live recovery of both panels used the escalation path: the
  two-step *mode* bounce (docs/hyprland.md Learned behaviours), which forces a
  real DP link retrain when DPMS cycling isn't enough. Also recorded in
  docs/hyprland.md: `hyprctl dispatch '<lua expr>'` shorthand works
  (`hl.dsp.dpms("off", "DP-3")`) and is simpler than
  `hyprctl eval 'hl.dispatch(...)'`.

## 2026-07-11

- **Creation** — [ssh-private-hosts dual module](ssh-private-hosts.md):
  the k-only sops ssh hosts setup generalised across machines. The sops file
  moved `modules/hosts/k/ssh-hosts.yaml` → shared
  `modules/hosts/ssh-hosts.yaml`, re-encrypted with nebula as a second
  recipient (fresh encryption from k's deployed `/run/secrets` plaintext read
  over ssh — public recipients only, no host-key decryption); twin modules
  deploy it to `~/.ssh/config.d/private-hosts` per OS (darwin gated
  `programs.ssh-private-hosts.enable`, on for k; nixos universal + tmpfiles
  for the k-owned `~/.ssh/config.d`). `home/ssh` is now cross-platform
  (relative `Include config.d/*`, per-OS 1Password `IdentityAgent` via
  `Match exec uname`) and left the nixos stow skip list. Verified: nebula
  age key (1Password) decrypts to byte-identical content; nebula toplevel
  builds; darwin k/mini cross-eval with the gate true/false.

## 2026-07-10

- **Update** — [claude-account-selector](claude-account-selector.md) /
  [claude-profile-isolation](../decisions/claude-profile-isolation.md): new
  `fallbackProfile` option symlinks `~/.claude` → `~/.claude-<profile>` at
  activation (order 1601), closing the env-loss hole where a desktop launch
  that misses the LaunchAgent's `CLAUDE_CONFIG_DIR` (login race / var-less
  relaunch chain, seen 2026-06-28 and 2026-07-10) silently grows a stray
  config tree in `~/.claude`. Activation never deletes a real `~/.claude`
  directory — it warns and waits for a hand migration. Host `k` sets
  `fallbackProfile = "me"`. Trade-off recorded: env-loss is now silent, and
  a work session that misses the env var lands in the personal profile.

- **Creation** — [helium-chrome-shim](helium-chrome-shim.md) /
  [decision](../decisions/helium-chrome-shim.md): dropped the chromium cask from
  [homebrew](homebrew.md) (Helium is the browser now), which broke
  chrome-devtools-mcp on the Macs — Puppeteer probes the literal
  `/Applications/Google Chrome.app/…` path for channel `stable`
  (existence-only, no env override) and the Claude Code plugin passes no
  browser flag (plugin MCP args aren't user-overridable). Fix (Kris' idea): a
  nix-darwin activation script plants a 2-line `exec` wrapper at that exact
  path → Helium; `exec` keeps the PID so launch/close semantics are
  unchanged. Verified the full matrix (headful/headless × isolated/persistent
  × SIGTERM/stdin-EOF close × `--browserUrl` attach) — all pass, no orphaned
  processes; live plugin tools drove Helium without a session restart.
  Guarded: no-op/self-clean without Helium.app, never touches a real Chrome
  (Mach-O vs `#!`). Also documented in `docs/helium.md`; homebrew.md stub
  upgraded (zap-cleanup gotcha).

## 2026-07-05

- **Update** — [codebase-memory-mcp](codebase-memory-mcp.md) is now a
  Dual Module: the fork (`1d99463`) gained
  `nixosModules.codebase-memory-mcp` — a systemd user service twin of the
  launchd agent, same `cbm-daemon` FIFO wrapper — and cross-platform
  `cbm-tools` (cbm-ctl grew a compile-time `systemctl --user`/`journalctl`
  backend; the server build needed `patchShebangs` because the Linux sandbox
  lacks `/usr/bin/env`). Re-exported by `modules/nixos/codebase-memory-mcp.nix`
  and enabled on [nebula](../hosts/nebula.md) via
  [nebula-codebase-memory-mcp](nebula-codebase-memory-mcp.md);
  verified live (unit active, UI on :9749, cbm-ctl status/restart).

## 2026-07-04

- **Update** — [dnsmasq](dnsmasq.md): filled in the previously
  stub description with what dnsmasq actually is (lightweight DNS
  forwarder/cache + DHCP/router-advertisement/network-boot infra) and how
  this repo uses it (loopback-bound local resolver for `localhost`/`p4c`,
  not a network-facing server); added `## Citations` linking the upstream
  docs, man page, and the nix-darwin `services.dnsmasq` option reference.

## 2026-07-03

- **Creation** — nebula's Nix implementation swapped from Lix to Determinate
  Nix via the new [determinate](determinate.md) nixos-class module
  (imports the determinate flake input's NixOS module; snowglobe-lib unforked —
  its `setDefault`/1337 `nix.package = lix` loses to the module's plain
  assignment). Motive: Lix lacks Nix ≥2.26 relative-path input locking
  (lix#641, Flakes frozen), so the `./flakes/*` sub-flake inputs re-locked to
  machine-local store paths on every rebuild, churning `flake.lock` twice per
  `nrs` plus every direnv reload. The lock's sub-flake nodes are now stable
  relative paths with a `parent` field; lazy trees also stop the dirty-tree
  store copies. Full rationale:
  [Replace Lix With Determinate Nix](../decisions/lix-to-determinate.md).

- **Update** — nrs/nrt became real executables and gained a sibling: the
  [nh](nh.md) module now ships `writeShellScriptBin` helpers `nrs`
  (nh darwin switch), `nrb` (nh darwin build — no root, safe for agent
  harnesses), and `nrt` (darwin-rebuild check; both `nh darwin test` and
  `darwin-rebuild test` have been removed upstream, so the old nrt alias was
  silently broken). The `environment.shellAliases` block left core.nix —
  aliases only exist in interactive zsh, which is why `nrs` was unavailable
  from non-interactive shells.
