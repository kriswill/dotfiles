# Generation retention and boot-menu safety (report P15,
# docs/nrs-pipeline.html; decision: knowledge/decisions/generation-retention.md).
#
# Retention by boot history. snowglobe's nightly nix-gc ran
# `nix-collect-garbage --delete-older-than 7d`. That kept a week of
# switches, but no system that had actually booted unless it was recent: on
# 2026-10-24 the generation behind every earlier boot, kernel 7.2.10's
# included, was already gone. nix-gc now only collects garbage, and its
# preStart prunes first (./prune-generations.sh). The system profile keeps:
#   - the current boot;
#   - the previous `prevBoots` systems that booted successfully;
#   - the newest one on a different kernel semver (MAJOR.MINOR.PATCH, so
#     rebuilds and -zen1/-rc1 suffixes do not count);
#   - the boot default and the running system;
#   - the previous good switch: the newest other system whose activation
#     switch-to-configuration logged as finished (exit 0, all units started).
# Boots and switches are read from the persistent journal. Every other profile
# keeps the old rule of `keepDays` days. Deletion goes through nix-env, which
# never deletes a current generation. nh clean was passed over because it
# removes generation links itself and can delete the one a rolled-back profile
# points at.
#
# Boot-menu safety. Every bootloader install roots each system the GRUB menu
# lists (./grub-menu-roots.sh, in /nix/var/nix/gcroots/grub-menu), so no GC
# can collect a closure the menu boots. That covers the timer, a manual
# nix-collect-garbage -d and nh clean. That was the 2026-06-16
# emergency-mode boot. It runs inside switch-to-configuration's own
# bootloader step, so it needs no hook on GC and takes no lock of its own,
# and a failure fails that step visibly.
{
  flake.modules.nixos.generations =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      prevBoots = 2;
      keepDays = 7;
      prune = pkgs.writeShellApplication {
        name = "prune-generations";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnugrep
          pkgs.gnused
          pkgs.jq
          config.nix.package # nix-env, the system's own
          config.systemd.package # journalctl, matching the running journal
        ];
        text = builtins.readFile ./prune-generations.sh;
      };
      menuRoots = pkgs.writeShellApplication {
        name = "grub-menu-roots";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gnused
        ];
        text = builtins.readFile ./grub-menu-roots.sh;
      };
      grubCfgs = map (b: "${b.path}/grub/grub.cfg") config.boot.loader.grub.mirroredBoots;
    in
    {
      # Collect-only: generations are pruned by preStart, not by age alone.
      # (snowglobe's "--delete-older-than 7d" is a setDefault, which a plain
      # assignment outranks.)
      nix.gc.options = "";
      # The directories nix-collect-garbage --delete-older-than walks as root.
      # A prune failure fails the unit before anything is collected.
      systemd.services.nix-gc.preStart = ''
        ${lib.getExe prune} ${toString prevBoots} ${toString keepDays} /nix/var/nix/profiles /root/.local/state/nix/profiles
      '';
      environment.systemPackages = [ prune ]; # `prune-generations --dry 2 7 /nix/var/nix/profiles` previews

      boot.loader.grub.extraInstallCommands = ''
        ${lib.getExe menuRoots} /nix/var/nix/gcroots/grub-menu ${lib.escapeShellArgs grubCfgs}
      '';
    };
}
