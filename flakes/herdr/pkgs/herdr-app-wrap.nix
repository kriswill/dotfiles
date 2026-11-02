# The installed herdr-app on Linux: any herdr-app package (this flake's repack
# by default, nixpkgs' herdr-desktop or numtide's build work too) with the
# choices made outside the app. Returns `package` itself when there are none.
# macOS doesn't use it: Finder launches the bundle, not bin/herdr-app, so the
# darwin module writes the same choices into settings.json (../modules/darwin.nix).
#
# - telemetry = false sets HERDR_TELEMETRY=0, upstream's off switch for a run.
#   (It reaches every terminal through herdr-core, harmlessly: only herdr-app
#   reads it.)
# - settings, when non-empty, are merged into settings.json before each
#   launch by ./merge-settings.sh.
# - core, when given, goes at the END of PATH, so a herdr-core already on PATH
#   wins; for the standalone `nix run` package.
# - pinCore, when given, sets HERDR_CORE_DIRS to its bin, the only place the
#   app then looks for hc; the modules pass programs.herdr-core.package. The
#   app puts the folder it found hc in FIRST on its PATH (upstream
#   src/core_bin.rs `use_core`), and herdr-core hands that PATH to every
#   terminal. Found in /run/current-system/sw/bin, that put the plain sudo
#   ahead of /run/wrappers/bin's setuid one in every pane ("sudo must be
#   owned by uid 0"). The core's own bin holds only hc and herdr-core, so
#   leading with it shadows nothing. HERDR_CORE_DIRS itself reaches the
#   terminals too, harmlessly: only herdr-app reads it.
{
  lib,
  callPackage,
  symlinkJoin,
  makeWrapper,
  writeText,
  package,
  core ? null,
  pinCore ? null,
  telemetry ? false,
  settings ? { },
}:
let
  merge = callPackage ./herdr-app-merge-settings.nix { };
  declared = writeText "herdr-app-settings.json" (builtins.toJSON settings);
  args =
    lib.optionals (!telemetry) [
      "--set"
      "HERDR_TELEMETRY"
      "0"
    ]
    ++ lib.optionals (pinCore != null) [
      "--set"
      "HERDR_CORE_DIRS"
      "${lib.getBin pinCore}/bin"
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
