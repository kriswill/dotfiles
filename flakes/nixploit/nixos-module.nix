# NixOS module, exported as `nixosModules.nixploit` (and `default`).
# Parameterized over this flake's inputs: it imports upstream's module
# (services.nixploit.*: the scheduled feed update + scan, its state under
# /var/lib/nixploit and the node_exporter metrics) and adds the report step
# and its readers under services.nixploit.report.
inputs:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nixploit;
  stateDirectory = "/var/lib/nixploit";
  # Built against the Nix the daemon runs, so path-info speaks its protocol.
  graph = pkgs.callPackage ./report-graph.nix { nix = config.nix.package; };
  report = pkgs.callPackage ./report.nix { nixploit-report-graph = graph; };
in
{
  imports = [ inputs.upstream.nixosModules.default ];

  options.services.nixploit.report = {
    enable = lib.mkEnableOption ''
      rendering ${stateDirectory}/report.html after every run: a standalone
      viewer with the report and the running system's dependency graph
      embedded (why each vulnerable package is installed, what to do about it),
      readable by the nixploit group and openable straight from file://
    '';

    readers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "alice" ];
      description = ''
        Users who may read the scan results without sudo. They join the
        `nixploit` group, and report.json is made group-readable after every
        run (upstream writes it 0600; report.html is always 0640).

        New group membership reaches a desktop session only once the user's
        systemd user manager restarts, which on a desktop that keeps it
        running across logouts means a reboot. Until then,
        `sg nixploit -c 'cat ${stateDirectory}/report.html'` works.
      '';
    };
  };

  options.services.nixploit.rescanOnSwitch = lib.mkEnableOption ''
    rescanning 2 to 17 minutes (upstream's OnActiveSec plus its randomized
    delay) after a switch that changes the installed packages
    (environment.systemPackages or any user's packages), instead of leaving
    the report stale until the next calendar run
  '';

  # Upstream's ExecStopPost is a single string; these lists merge with it, and
  # every entry runs. `-` ignores failures before a first report exists.
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf (cfg.report.readers != [ ]) {
        users.users = lib.genAttrs cfg.report.readers (_: {
          extraGroups = [ "nixploit" ];
        });
        systemd.services.nixploit.serviceConfig.ExecStopPost = [
          "-${pkgs.coreutils}/bin/chmod g+r ${stateDirectory}/report.json"
        ];
      })
      (lib.mkIf cfg.report.enable {
        systemd.services.nixploit.serviceConfig.ExecStopPost = [ "-${lib.getExe report}" ];
      })
      # Upstream keys the timer to its job config (X-Job): a switch that
      # changes the timer's unit file restarts it, and OnActiveSec=2min fires
      # a scan. Key it to the installed packages too: not the toplevel, which
      # contains this unit (infinite recursion). Hashed, since the value only
      # has to change.
      (lib.mkIf cfg.rescanOnSwitch {
        systemd.timers.nixploit.unitConfig.X-Packages = builtins.hashString "sha256" (
          toString (
            [ config.system.path ] ++ lib.concatMap (user: user.packages) (lib.attrValues config.users.users)
          )
        );
      })
    ]
  );
}
