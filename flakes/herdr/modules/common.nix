# The options and OS-independent config shared by ./nixos.nix and ./darwin.nix,
# which add what only their OS can do (linger, tmpfiles and systemd timers;
# activation-script links and a launchd agent). Takes this flake's `self` for
# the herdr TUI, whose package comes from the fork's own flake; the other
# packages are built from ../pkgs against the system's pkgs.
#
#   programs.herdr-cli       the herdr TUI (our fork) + herdr-nav
#   programs.herdr-core      hc, the terminal daemon
#   programs.herdr-app       the Herdr window (Linux only for now)
#   services.herdr-update-check   releases past ours, stale running builds
#
# Config files are opt-in. Each file option defaults to null, which leaves the
# file alone: write it yourself, or link it in from a dotfiles repo (Herdr's
# own saves write through symlinks, so a linked settings.json collects them).
self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cli = config.programs.herdr-cli;
  core = config.programs.herdr-core;
  app = config.programs.herdr-app;
  check = config.services.herdr-update-check;
  inherit (pkgs.stdenv.hostPlatform) system;
  json = pkgs.formats.json { };
  toml = pkgs.formats.toml { };
in
{
  options = {
    programs = {
      herdr-cli = {
        enable = lib.mkEnableOption "herdr, the terminal agent multiplexer, from our fork (`herdr`)";

        package = lib.mkOption {
          type = lib.types.package;
          default = self.packages.${system}.herdr-cli or (throw "herdr-cli: no package for ${system}");
          defaultText = lib.literalMD "our fork's build, this flake's `herdr-cli` package";
          description = "The herdr package; its `bin` provides `herdr`.";
        };

        nav.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Install herdr-nav, vim-aware ctrl+h/j/k/l pane navigation: the
            herdr-side half of a Neovim integration, bound as a `[[keys.command]]`
            in herdr's config.toml. It runs `package` by store path, since the
            herdr server spawns it with a PATH we don't control.
          '';
        };

        python = lib.mkPackageOption pkgs "python3" {
          nullable = true;
          extraDescription = ''
            herdr's agent integration hooks (Claude's `herdr-agent-state.sh`)
            report the session id over the herdr socket with python3, and exit
            silently without it. Without that report herdr can't resume agent
            sessions after a server restart. `null` installs none.
          '';
        };
      };

      herdr-core = {
        enable = lib.mkEnableOption "herdr-core (`hc`), which runs terminals and coding agents that keep running after you leave";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.callPackage ../pkgs/herdr-core.nix { };
          defaultText = lib.literalMD "upstream's release build, from this flake's `pkgs/herdr-core.nix`";
          description = "The herdr-core package; its `bin` provides `herdr-core` and `hc`.";
        };

        users = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "alice" ];
          description = ''
            Existing users who run hc. They get the config files declared by
            `settings` here and by `programs.herdr-app.keys` (under their home's
            `.config`), the update check's unit on NixOS, and linger on NixOS.
          '';
        };

        settings = lib.mkOption {
          type = lib.types.nullOr toml.type;
          default = null;
          example = {
            shell = [
              "zsh"
              "-l"
            ];
            history_mb = 20;
            detach_key = "ctrl+]";
          };
          description = ''
            `~/.config/herdr-core/config.toml` for each of `users`, as a link to
            the Nix store. Keys (all optional): `shell` (argv for new shells,
            default `$SHELL`), `detach_key` (`ctrl+<key>`, default `ctrl+\`),
            `wait_timeout` (seconds, default 180), `notes` (bool), `notes_quiet`
            (seconds), `headless` (`COLSxROWS`), `history_mb` (scrollback per
            terminal, default 5), `socket`, `machine_timeout` (seconds). Changes
            apply to the next new shell; no restart is needed.

            `null` leaves the file alone. The core only reads it, so a symlink
            from a dotfiles repo works.
          '';
        };
      };

      herdr-app = {
        enable = lib.mkEnableOption "Herdr, the desktop app for herdr-core's terminals and agents (turns on programs.herdr-core)";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.callPackage ../pkgs/herdr-app.nix { };
          defaultText = lib.literalMD "upstream's release build, from this flake's `pkgs/herdr-app.nix`";
          example = lib.literalExpression "pkgs.herdr-desktop";
          description = ''
            The app before wrapping. Any package with `bin/herdr-app` works, such
            as a source build from nixpkgs or numtide's llm-agents.nix.
          '';
        };

        finalPackage = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          description = "The installed app: `package` wrapped for `telemetry` and `settings`.";
        };

        telemetry = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Let the app send its daily usage report (on by default upstream:
            versions, OS, bucketed usage counts, known agent names; no terminal
            text or paths). `false` runs it with `HERDR_TELEMETRY=0`, whatever
            settings.json or the Settings screen say.
          '';
        };

        settings = lib.mkOption {
          inherit (json) type;
          default = { };
          example = {
            font = "JetBrainsMono Nerd Font";
            font_size = 13;
            sounds.enabled = false;
          };
          description = ''
            Settings merged into `settings.json` in the app's home before each
            launch (`$HERDR_APP_HOME`, else `~/.config/herdr-app`), declared keys
            winning. Anything not declared stays as the app saved it, and an edit
            to a declared key lasts until the next launch. A symlinked
            settings.json is written through. Keys include `font`, `font_size`,
            `ui_font`, `theme`, `appearance`, `colors`, `sounds`, `zoom`,
            `clipboard_write`, `minimum_contrast` and `core` (the hc path).

            `{ }` (the default) never touches settings.json.
          '';
        };

        keys = lib.mkOption {
          type = lib.types.nullOr json.type;
          default = null;
          description = ''
            `~/.config/herdr-app/keys.json` for each of programs.herdr-core's
            `users`: the app's key bindings, reloaded live. It replaces the
            defaults, which the app writes there only when the file is missing;
            `herdr-app commands` lists the actions.

            `null` leaves the file alone. The app only reads it, so a symlink
            from a dotfiles repo works.
          '';
        };
      };

    };

    services.herdr-update-check = {
      enable = lib.mkEnableOption ''
        a daily desktop notification when upstream releases past an enabled
        herdr (the fork behind programs.herdr-cli, herdr-core, herdr-app), or
        when a running server, core or window is older than the installed
        build. Each release gets a button opening its release page or changelog
        (Linux; macOS notifications have none). The schedule is OS-specific:
        `calendar` on NixOS, `startCalendarInterval` on nix-darwin
      '';

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.callPackage ../pkgs/herdr-update-check.nix { cliVersion = cli.package.version; };
        defaultText = lib.literalMD "this flake's `pkgs/herdr-update-check.nix`";
        description = "The herdr-update-check package.";
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        readOnly = true;
        description = ''
          The versions the scheduled check compares against: the configured
          packages', empty (skipped) for a program that isn't enabled.
        '';
      };
    };

  };

  config = lib.mkMerge [
    {
      programs.herdr-app.finalPackage = pkgs.callPackage ../pkgs/herdr-app-wrap.nix {
        inherit (app) package telemetry settings;
      };
      services.herdr-update-check.environment = {
        HERDR_CLI_VERSION = if cli.enable then cli.package.version else "";
        HERDR_CORE_VERSION = if core.enable then core.package.version else "";
        HERDR_APP_VERSION = if app.enable then app.package.version else "";
      };
    }

    (lib.mkIf cli.enable {
      environment.systemPackages = [
        cli.package
      ]
      ++ lib.optional cli.nav.enable (pkgs.callPackage ../pkgs/herdr-nav.nix { herdr = cli.package; })
      ++ lib.optional (cli.python != null) cli.python;
    })

    (lib.mkIf core.enable {
      environment.systemPackages = [ core.package ];
      warnings = lib.optional (core.settings != null && core.users == [ ]) ''
        programs.herdr-core.settings is set but programs.herdr-core.users is
        empty, so no config.toml is written.
      '';
    })

    (lib.mkIf app.enable {
      programs.herdr-core.enable = lib.mkDefault true;
      environment.systemPackages = [ app.finalPackage ];
      warnings =
        lib.optional (app.keys != null && core.users == [ ]) ''
          programs.herdr-app.keys is set but programs.herdr-core.users is
          empty, so no keys.json is written.
        ''
        ++
          lib.optional
            (
              core.enable
              && (app.package.coreMin or null) != null
              && lib.versionOlder core.package.version app.package.coreMin
            )
            ''
              herdr-app ${app.package.version} needs herdr-core >= ${app.package.coreMin}, but
              programs.herdr-core.package is ${core.package.version}; the app will
              refuse it and offer to install its own.
            '';
    })

    (lib.mkIf check.enable {
      warnings = lib.optional (!(cli.enable || core.enable || app.enable)) ''
        services.herdr-update-check is enabled but none of programs.herdr-cli,
        programs.herdr-core and programs.herdr-app is, so it checks nothing.
      '';
    })
  ];
}
