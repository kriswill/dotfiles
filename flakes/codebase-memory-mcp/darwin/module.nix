# nix-darwin module for codebase-memory-mcp, exported as
# `darwinModules.codebase-memory-mcp`. Parameterized over this flake's `self` so
# `package`/`tools` default to the flake's own builds for the host system —
# consumers need no overlay or callPackage wiring (mirrors apple-container).
#
# It runs the daemon under launchd as a user agent: the binary has no daemon
# mode (its HTTP UI + git-watcher are background threads of the stdio MCP server,
# which exits on stdin EOF), so cbm-daemon hands it a never-EOF stdin via a FIFO
# and execs it in the foreground. launchd then tracks the real PID directly —
# KeepAlive restarts on crash, SIGTERM (bootout/kickstart -k) shuts it down
# through the server's own graceful handler.
self:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.kriswill.codebase-memory;
  user = config.system.primaryUser;
  homeDir = "/Users/${user}";
  sys = pkgs.stdenv.hostPlatform.system;
  cbmTools = self.packages.${sys}.cbm-tools;
in
{
  options.kriswill.codebase-memory = {
    enable = lib.mkEnableOption "launchd-supervised codebase-memory-mcp daemon + control CLI (cbm-ctl)";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${sys}.codebase-memory-mcp;
      defaultText = lib.literalExpression "codebase-memory-mcp.packages.\${system}.codebase-memory-mcp";
      description = "The codebase-memory-mcp package to supervise.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9749;
      description = "TCP port for the codebase-memory-mcp HTTP UI / daemon.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Registering here turns a null system.primaryUser into nix-darwin's friendly
    # migration assertion instead of a raw "cannot coerce null to a string"
    # (homeDir interpolates ${user} for the log paths below).
    system.requiresPrimaryUser = [ "kriswill.codebase-memory.enable" ];

    environment.systemPackages = [
      cfg.package # codebase-memory-mcp (also the bare stdio MCP server for .mcp.json)
      cbmTools # cbm-ctl + cbm-daemon
    ];

    # nix-darwin registers this as launchd label `org.nixos.codebase-memory-mcp`
    # (the org.nixos. prefix is nix-darwin's convention — see org.nixos.claude-config-dir).
    # cbm-ctl targets that exact label, and the log filenames below match it.
    # KeepAlive supervises; ProcessType=Background + LowPriorityIO + Nice keep the
    # watcher's reindexing off concurrent clients.
    launchd.user.agents."codebase-memory-mcp".serviceConfig = {
      ProgramArguments = [ "${cbmTools}/bin/cbm-daemon" ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
      LowPriorityIO = true;
      Nice = 5;
      ThrottleInterval = 10;
      StandardOutPath = "${homeDir}/Library/Logs/org.nixos.codebase-memory-mcp.out.log";
      StandardErrorPath = "${homeDir}/Library/Logs/org.nixos.codebase-memory-mcp.err.log";
      EnvironmentVariables = {
        CBM_BIN = lib.getExe cfg.package;
        CBM_PORT = toString cfg.port;
      };
    };
  };
}
