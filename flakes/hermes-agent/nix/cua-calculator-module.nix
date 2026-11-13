# Ours: opt-in, manual GUI-session deployment. No launchd job, activation-time
# launch, permission grants, LaunchServices or Apple-events sandbox exceptions.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.hermes-agent;
  deployment = pkgs.callPackage ./cua-calculator.nix { inherit (cfg) user; };
  writable = [ cfg.stateDir ] ++ cfg.sandbox.readWritePaths;
in
{
  options.services.hermes-agent.cuaCalculator.enable = lib.mkEnableOption ''
    the signed, user-launched Calculator-only CuaDriver endpoint
  '';

  config = lib.mkIf (cfg.enable && cfg.cuaCalculator.enable) {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "aarch64-darwin";
        message = "The pinned signed CuaDriver deployment supports aarch64-darwin only.";
      }
      {
        assertion = lib.all (
          root: !(lib.hasPrefix (lib.removeSuffix "/" root + "/") (deployment.directory + "/"))
        ) writable;
        message = "The trusted CuaDriver endpoint must be outside every Hermes-writable directory.";
      }
      {
        assertion = cfg.sandbox.enable;
        message = "The Calculator-only endpoint is intended for the Seatbelt-confined Hermes client.";
      }
    ];

    environment.systemPackages = [
      deployment.driver
      deployment.control
    ];
    services.hermes-agent = {
      # The existing sandbox renderer emits a literal network-outbound grant.
      # It grants no directory writes, socket binds, Apple events or GUI launch.
      sandbox.unixSockets = [ deployment.socketPath ];
      environment.HERMES_CUA_DRIVER_CMD = deployment.binary;
      settings = {
        # Upstream v0.23.0 defaults to hermes-cli (which includes computer_use).
        # Retain that bundle and declare the specific toolset explicitly; do not
        # replace the default bundle with a computer-use-only tool list.
        toolsets = [
          "hermes-cli"
          "computer_use"
        ];
        computer_use = {
          backend = "cua";
          external_socket = deployment.socketPath;
          autostart = false;
          permission_mode = "bounded";
          capability_manifest = toString deployment.manifest;
          allow_unsigned_driver = false;
          cua_telemetry = false;
          # AX-only Calculator exercise; the manifest denies display capture
          # and driver-configuration tools, including screenshot size changes.
          capture_after_mode = "ax";
          max_image_dimension = 0;
        };
      };
    };
  };
}
