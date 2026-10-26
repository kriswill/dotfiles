# packages

Custom packages, nixpkgs overlays, and the self-contained sub-flakes the root
flake consumes via relative-path inputs.

## Concepts

* [apple-container](apple-container.md) - apple-container — Apple's native macOS container CLI, repackaged from the signed .pkg release.
* [battlenet](battlenet.md) - Sub-flake that runs Blizzard's Battle.net in nixpkgs' GE-Proton without Steam or umu: a host-side `battlenet` launcher that keeps one wineserver per prefix and hands Proton to a steam.buildRuntimeEnv sandbox, installs Battle.net into a configurable prefix on first run, plus the programs.battlenet NixOS module; enabled on nebula.
* [btop](btop.md) - Patch overlay on btop, the terminal resource monitor: on Linux, the CPU box colours the core labels of the CPUs sharing the largest L3 (nebula's 3D V-Cache CCD) in the Cached meter's colour; darwin keeps the cached build.
* [Cbissue](cbissue.md) - cbissue — open Codeberg (Forgejo) issues from the CLI.
* [Cbissues](cbissues.md) - cbissues — browse/filter a Codeberg (Forgejo) repo's issues (fzf TUI + --plain).
* [ccglass](ccglass.md) - ccglass — local logging reverse-proxy + web dashboard for coding agents, built as a standalone binary.
* [Direnv](direnv.md) - Nixpkgs overlay 'direnv'.
* [dotbar](dotbar.md) - Braille-dot progress bar CLI for statuslines and terminals, consumed straight from the tlehman/dotbar flake.
* [Dots Adopt](dots-adopt.md) - Custom Nix package 'dots-adopt'.
* [Flatpak User](flatpak-user.md) - A drop-in `flatpak` that defaults the CLI to the per-user installation.
* [Gh Config](gh-config.md) - Snapshot/restore gh's config.yml between ~/.config/gh (app-owned) and config/gh/ — gh's atomic-rename saves break stow symlinks, so it left the stow tree for the snapshot pattern.
* [gh-op](gh-op.md) - Linux-only gh wrapper sourcing GH_TOKEN from 1Password at runtime — via a vault-scoped service-account token when deployed, desktop-app auth otherwise — so ~/.config/gh/hosts.yml holds no plain-text token on nebula's unencrypted disk.
* [Helium Config](helium-config.md) - Custom Nix package 'helium-config'.
* [Herdr Nav](herdr-nav.md) - herdr-nav — a keybinding shim that gives herdr the vim-aware pane switching tmux gets from is_vim + if-shell — forwarding ctrl+h/j/k/l to a pane running vim instead of moving pane focus.
* [Iv](iv.md) - A command-line image viewer using terminal graphics.
* [Kitten](kitten.md) - Kitten - A collection of small, useful programs for the kitty terminal.
* [Ld64 Lld](ld64-lld.md) - TEMPORARY overlay linking kitty/vfkit/starship with LLVM lld on darwin — works around the pinned nixpkgs' cctools ld64 1010.6 SIGTRAP until the staging fix reaches nixos-unstable.
* [nixploit](nixploit.md) - Sub-flake wrapping the manic-systems/nixploit vulnerability scanner for NixOS: re-exports its package and module and adds services.nixploit.report (an HTML viewer rendered after every scan, which explains why each vulnerable package is installed and what to do about it, plus the users who can read it) and services.nixploit.rescanOnSwitch; enabled on nebula.
* [Noctalia Config](noctalia-config.md) - Custom Nix package 'noctalia-config'.
* [Nrs](nrs.md) - The rebuild helper for NixOS and nix-darwin, one bash script: nom for the build tree, dix for the diff, the platform's own activation, and a state report on every exit. It replaced nh on 2026-10-24 (it was nrs2 until then).
* [okf](okf.md) - okf — CLI for maintaining OKF knowledge bundles (scaffold/index/validate/viz), consumed from its own repo via FlakeHub (kriswill/okflight).
* [Pass Xdg](pass-xdg.md) - pass-xdg — a drop-in `pass` (standard unix password manager) that defaults its store to an XDG-compliant location instead of the upstream default `~/.password-store`.
* [Podman](podman.md) - Podman — the daemonless, Docker-compatible container engine; on macOS packaged from the official prebuilt darwin_arm64 remote client (nixpkgs' podman refuses to evaluate on darwin) with vfkit + gvproxy bundled in, primarily serving minikube's podman driver for work Kubernetes.
* [Slack Leave Devopsinc](slack-leave-devopsinc.md) - Bash CLI (+ Spotlight app) that leaves every Slack `devopsinc-N` incident channel (N >= 1000) the PagerDuty routine auto-adds Kris to, via the Slack Web API with a Keychain-held user token.
* [System Update Report](system-update-report.md) - HTML "what changed" page after a rebuild: nvd diff of the booted (NixOS) or previous (darwin) generation vs current, plus the latest flake.lock commit parsed into a flake-input from/to table.
* [Tomato](tomato.md) - CLI to get/set TOML values preserving comments and formatting.
* [Wowup](wowup.md) - WowUp-CF (the CurseForge fork of WowUp), packaged from the upstream AppImage (github.com/WowUp/WowUp.CF releases).
