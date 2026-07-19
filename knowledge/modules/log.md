# Log

## 2026-07-19

- **Creation** — [rtk](rtk.md): cross-OS twin (`modules/darwin/rtk.nix` /
  `modules/nixos/rtk.nix`) mounting the [rtk package](../packages/rtk.md) onto
  `environment.systemPackages`. Registering `pkgs.rtk` under
  `perSystem.packages` alone (as first done) only creates a flake output
  (`nix build .#rtk`) — it never reaches a host's own `pkgs`, so `nrs`/nixos-
  rebuild installed nothing until the [overlay](overlays.md) plus these
  module twins were added (see the [add-package playbook](../playbooks/add-package.md)
  step 3, easy to skip for a package that also happens to build standalone).

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
