# The installed herdr-app: any herdr-app package (this flake's repack by
# default, nixpkgs' herdr-desktop or numtide's build work too) with the
# choices made outside the app. Returns `package` itself when there are none.
#
# - telemetry = false sets HERDR_TELEMETRY=0, upstream's off switch for a run.
#   (It reaches every terminal through herdr-core, harmlessly: only herdr-app
#   reads it.)
# - settings, when non-empty, are merged into settings.json before each
#   launch by ./merge-settings.sh.
# - core, when given, goes at the END of PATH, so a herdr-core already on PATH
#   wins; for the standalone `nix run` package. The NixOS module passes none:
#   it installs the core system-wide, and the app looks in
#   /run/current-system/sw/bin itself, so no PATH leaks into terminals.
{
  lib,
  symlinkJoin,
  makeWrapper,
  writeShellApplication,
  writeText,
  coreutils,
  jq,
  package,
  core ? null,
  telemetry ? false,
  settings ? { },
}:
let
  merge = writeShellApplication {
    name = "herdr-app-merge-settings";
    runtimeInputs = [
      coreutils
      jq
    ];
    text = builtins.readFile ./merge-settings.sh;
  };
  declared = writeText "herdr-app-settings.json" (builtins.toJSON settings);
  args =
    lib.optionals (!telemetry) [
      "--set"
      "HERDR_TELEMETRY"
      "0"
    ]
    ++ lib.optionals (core != null) [
      "--suffix"
      "PATH"
      ":"
      "${lib.getBin core}/bin"
    ]
    ++ lib.optionals (settings != { }) [
      "--run"
      "${lib.getExe merge} ${declared} || true"
    ];
in
if args == [ ] then
  package
else
  symlinkJoin {
    name = "herdr-app-${package.version}";
    paths = [ package ];
    nativeBuildInputs = [ makeWrapper ];
    postBuild = ''
      rm $out/bin/herdr-app
      makeWrapper ${lib.getExe package} $out/bin/herdr-app ${lib.escapeShellArgs args}
      # A launcher entry naming the unwrapped binary by its store path would
      # bypass the wrapper; point it here instead (ours says a bare herdr-app).
      for f in $out/share/applications/*.desktop; do
        if grep -q ${package}/bin/herdr-app "$f"; then
          cp --remove-destination "$(readlink -f "$f")" "$f"
          chmod u+w "$f"
          sed -i "s|${package}/bin/herdr-app|$out/bin/herdr-app|g" "$f"
        fi
      done
    '';
    passthru = (package.passthru or { }) // {
      inherit (package) version;
      unwrapped = package;
    };
    inherit (package) meta;
  }
