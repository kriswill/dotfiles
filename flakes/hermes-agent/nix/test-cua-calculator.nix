# Ours: pure policy/package assertions plus non-GUI launcher regression tests.
{ pkgs }:
let
  deployment = pkgs.callPackage ./cua-calculator.nix { user = "k"; };
  manifest = deployment.manifestValue;
in
assert manifest.version == 3;
assert !(manifest ? mode) && !(manifest ? ask);
assert manifest.expires_after == "15m" && manifest.idle_timeout == "5m";
assert
  manifest.allow.tools == [
    "start_session"
    "end_session"
    "launch_app"
    "get_window_state"
    "click"
    "type_text"
    "press_key"
  ];
assert
  manifest.resources == {
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
assert deployment.socketPath == "/Users/k/Library/Caches/hermes-cua-calculator/driver.sock";
assert deployment.driver.dontFixup;
pkgs.runCommand "hermes-cua-calculator-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  cp ${./cua-calculator-control.py} cua-calculator-control.py
  cp ${./test-cua-calculator.py} test-cua-calculator.py
  python3 test-cua-calculator.py
  touch "$out"
''
