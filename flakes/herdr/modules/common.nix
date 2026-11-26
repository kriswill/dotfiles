# The options and OS-independent config shared by ./nixos.nix and ./darwin.nix,
# which add what only their OS can do (linger, tmpfiles and systemd timers;
# activation-script links and a launchd agent). Takes this flake's `self` for
# the herdr TUI, whose package comes from the fork's own flake; the other
# packages are built from ../pkgs against the system's pkgs.
#
#   programs.herdr-cli       the herdr TUI (our fork) + herdr-nav
#   programs.herdr-core      hc, the terminal daemon
#   programs.herdr-app       the Herdr window
#   programs.herdr-md        a markdown viewer mod for the window, and mdh
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
  md = config.programs.herdr-md;
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

        browser = {
          enable = lib.mkEnableOption ''
            herdr-open as `$BROWSER`: a link a program opens in an hc terminal
            (a click in Claude Code, `gh … --web`) opens in the browser of the
            machine whose Herdr window shows the terminal to you, whichever
            machine runs it. Needs the herdr-open mod in Herdr on the viewing
            machine; without an answer from one it opens here, as before. Set
            for login shells and for the core's environment, which every
            terminal inherits: terminals started by a core that predates the
            change don't have it (`hc server restart` after logging in again)'';

          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.callPackage ../pkgs/herdr-open.nix { };
            defaultText = lib.literalMD "this flake's `pkgs/herdr-open.nix`";
            description = "The herdr-open package.";
          };

          path = lib.mkOption {
            type = lib.types.str;
            readOnly = true;
            default = "/run/current-system/sw/bin/herdr-open";
            description = ''
              What `BROWSER` is set to: herdr-open through the system profile,
              a path that survives rebuilds (a store path would go stale in a
              long-lived core's environment).
            '';
          };
        };

        askpass = {
          enable = lib.mkEnableOption ''
            herdr-askpass, a `SUDO_ASKPASS` for agents: when sudo in an hc
            terminal has no terminal to ask on (an agent's shell), its
            password prompt opens as a dialog in the Herdr window that shows
            you that terminal, on whichever machine you're looking from. Needs
            the herdr-askpass mod in Herdr there; with no answer it times out
            and sudo fails. This only installs it at `path`. Set
            `SUDO_ASKPASS` and `DISPLAY` in the agent's own environment
            (Claude Code: `env` in `~/.claude/settings.json`): sudo uses an
            askpass on its own only with both set. It is deliberately not
            exported system-wide, because Homebrew adds `-A` to every sudo
            whenever `SUDO_ASKPASS` is set'';

          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.callPackage ../pkgs/herdr-askpass.nix { };
            defaultText = lib.literalMD "this flake's `pkgs/herdr-askpass.nix`";
            description = "The herdr-askpass package.";
          };

          path = lib.mkOption {
            type = lib.types.str;
            readOnly = true;
            default = "/run/current-system/sw/bin/herdr-askpass";
            description = ''
              What to set `SUDO_ASKPASS` to in an agent's environment:
              herdr-askpass through the system profile, a path that survives
              rebuilds.
            '';
          };
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
            text or paths). On Linux `false` runs it with `HERDR_TELEMETRY=0`,
            whatever settings.json or the Settings screen say. On macOS, where
            Finder launches the bundle and not a wrapper, `false` writes
            `telemetry: false` into each core user's settings.json at
            activation; the Settings screen can turn it back on until the next
            rebuild.
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
            Settings merged into `settings.json`, declared keys winning: on
            Linux into the app's home (`$HERDR_APP_HOME`, else
            `~/.config/herdr-app`) before each launch, on macOS into each of
            programs.herdr-core's `users`' `~/.config/herdr-app` at activation.
            Anything not declared stays as the app saved it, and an edit to a
            declared key lasts until the next launch (Linux) or rebuild (macOS).
            A symlinked settings.json is written through. Keys include `font`, `font_size`,
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

      herdr-md = {
        enable = lib.mkEnableOption ''
          herdr-md, a markdown viewer for Herdr (text, code, tables, images,
          video, typeset math and Mermaid, drawn natively), and `mdh`, the CLI
          that opens a file in it and highlights passages, built for agents.
          The mod is installed as `~/.config/herdr-app/mods/herdr-md` for each
          of programs.herdr-core's `users`: a real folder holding links to the
          package's files (a copy installed by hand has those replaced; its
          other files stay). A viewer opens only when
          asked for: `mdh open FILE`, or a keys.json binding of `pane.split`
          with `mod: "herdr-md"`. Mermaid needs a Chromium-family browser on
          PATH (or `CHROME_PATH`)'';

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.callPackage ../pkgs/herdr-md.nix { };
          defaultText = lib.literalMD "upstream at a pinned commit with our Linux patch, from this flake's `pkgs/herdr-md.nix`";
          description = ''
            The herdr-md package: `bin/mdh`, and the mod's files under
            `share/herdr-app/mods/<mod>`, where `mod` (the folder's name) and
            `modFiles` (its entries, which the modules link one by one) are
            attributes of the package.
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
          The versions the check compares against: the configured packages',
          empty (skipped) for a program that isn't enabled.
        '';
      };

      finalPackage = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = ''
          The installed check: `package` with `environment` set, so a run by
          hand, the schedule and the herdr-updates mod (`--json`) all compare
          against the configured packages rather than this flake's pins.
        '';
      };
    };

  };

  config = lib.mkMerge [
    {
      programs.herdr-app.finalPackage =
        if pkgs.stdenv.hostPlatform.isDarwin then
          # Finder launches the bundle, not a wrapper: ./darwin.nix writes the
          # telemetry choice, the settings and the core pin into settings.json.
          app.package
        else
          pkgs.callPackage ../pkgs/herdr-app-wrap.nix {
            inherit (app) package telemetry settings;
            # The app leads its PATH, and so every terminal's, with the folder it
            # found hc in; pin it to the core's own bin, not the system profile.
            pinCore = if core.enable then core.package else null;
          };
      services.herdr-update-check = {
        environment = {
          HERDR_CLI_VERSION = if cli.enable then cli.package.version else "";
          HERDR_CORE_VERSION = if core.enable then core.package.version else "";
          HERDR_APP_VERSION = if app.enable then app.package.version else "";
        };
        finalPackage =
          pkgs.runCommand "herdr-update-check"
            {
              nativeBuildInputs = [ pkgs.makeWrapper ];
              meta = check.package.meta or { } // {
                mainProgram = "herdr-update-check";
              };
            }
            ''
              makeWrapper ${lib.getExe check.package} $out/bin/herdr-update-check \
                ${lib.concatStringsSep " " (
                  lib.mapAttrsToList (name: value: "--set ${name} ${lib.escapeShellArg value}") check.environment
                )}
            '';
      };
    }

    (lib.mkIf cli.enable {
      environment.systemPackages = [
        cli.package
      ]
      ++ lib.optional cli.nav.enable (pkgs.callPackage ../pkgs/herdr-nav.nix { herdr = cli.package; })
      ++ lib.optional (cli.python != null) cli.python;
    })

    (lib.mkIf (core.enable && core.browser.enable) {
      environment.systemPackages = [ core.browser.package ];
    })

    (lib.mkIf (core.enable && core.askpass.enable) {
      environment.systemPackages = [ core.askpass.package ];
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

    (lib.mkIf md.enable {
      # mdh. The OS module links the mod's files into each core user's mods
      # folder.
      environment.systemPackages = [ md.package ];
      warnings = lib.optional (core.users == [ ]) ''
        programs.herdr-md is enabled but programs.herdr-core.users is empty,
        so only mdh is installed: the mod is linked into nobody's Herdr.
      '';
    })

    (lib.mkIf check.enable {
      # On PATH too, for a run by hand after a bump (the scheduled run waits
      # for its next slot) and for the herdr-updates mod's `--json` polls.
      environment.systemPackages = [ check.finalPackage ];
      warnings = lib.optional (!(cli.enable || core.enable || app.enable)) ''
        services.herdr-update-check is enabled but none of programs.herdr-cli,
        programs.herdr-core and programs.herdr-app is, so it checks nothing.
      '';
    })
  ];
}
