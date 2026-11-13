# Ours: immutable Calculator-only v3 policy and explicit trusted-user control.
# Schema: trycua/cua tag cua-driver-rs-v0.21.0, cua-driver-core/src/session_manifest.rs.
{
  pkgs,
  lib,
  user,
}:
let
  driver = pkgs.callPackage ./cua-driver.nix { };
  directory = "/Users/${user}/Library/Caches/hermes-cua-calculator";
  socketPath = "${directory}/driver.sock";
  manifestValue = {
    version = 3;
    expires_after = "15m";
    idle_timeout = "5m";
    allow.tools = [
      "start_session"
      "end_session"
      "launch_app"
      "get_window_state"
      "click"
      "type_text"
      "press_key"
    ];
    resources = {
      apps = [
        {
          bundle_id = "com.apple.calculator";
          launch = true;
          windows = "all";
          terminate = "deny";
        }
      ];
      desktop.display = false;
    };
  };
  manifest = pkgs.writeText "hermes-cua-calculator-v3.json" (builtins.toJSON manifestValue + "\n");
  app = "${driver}/Applications/CuaDriver.app";
  binary = "${app}/Contents/MacOS/cua-driver";
  script = pkgs.writeText "hermes-cua-calculator-control.py" (
    builtins.replaceStrings
      [ "@directory@" "@manifest@" "@app@" "@driver@" "@user@" ]
      [ directory (toString manifest) app binary user ]
      (builtins.readFile ./cua-calculator-control.py)
  );
  control = pkgs.writeShellScriptBin "hermes-cua-calculator" ''
    set -euo pipefail
    exec ${pkgs.python3}/bin/python3 -I ${script} "$@"
  '';
in
assert lib.hasPrefix "/Users/" directory;
{
  inherit
    driver
    directory
    socketPath
    manifestValue
    manifest
    app
    binary
    control
    ;
}
