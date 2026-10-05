# slack-leave-devopsinc — leave the Slack `devopsinc-N` incident channels a
# PagerDuty routine keeps auto-adding you to, on demand. The implementation
# lives in ./slack-leave-devopsinc.sh (plain bash, Slack Web API via curl/jq),
# wrapped with pinned runtime deps + ShellCheck via writeShellApplication.
#
# Alongside bin/ it ships "Leave devopsinc Channels.app" so Spotlight can launch
# it: an LSUIElement bundle (no Dock icon) that runs the CLI with --notify. Its
# CFBundleExecutable is a makeBinaryWrapper (native Mach-O) rather than a bare
# script, the same choice nixpkgs' writeDarwinBundle makes for wrapped execs.
# macOS-only: the token comes from /usr/bin/security, results go to
# /usr/bin/osascript notifications.
{
  lib,
  writeShellApplication,
  runCommand,
  makeBinaryWrapper,
  curl,
  jq,
}:
let
  name = "slack-leave-devopsinc";
  appName = "Leave devopsinc Channels";
  cli = writeShellApplication {
    inherit name;
    runtimeInputs = [
      curl
      jq
    ];
    text = builtins.readFile ./slack-leave-devopsinc.sh;
  };
  infoPlist = lib.generators.toPlist { escape = true; } {
    CFBundleDevelopmentRegion = "English";
    CFBundleDisplayName = appName;
    CFBundleExecutable = name;
    CFBundleIdentifier = "org.nixos.${name}";
    CFBundleInfoDictionaryVersion = "6.0";
    CFBundleName = appName;
    CFBundlePackageType = "APPL";
    CFBundleShortVersionString = "1.0";
    CFBundleVersion = "1";
    LSUIElement = true; # runs, notifies, exits — no Dock icon
  };
in
runCommand name
  {
    nativeBuildInputs = [ makeBinaryWrapper ];
    inherit infoPlist;
    passAsFile = [ "infoPlist" ];
    meta = {
      description = "Leave the Slack devopsinc-N incident channels (CLI + Spotlight app)";
      mainProgram = name;
      platforms = lib.platforms.darwin;
    };
  }
  ''
    app="$out/Applications/${appName}.app/Contents"
    mkdir -p "$out/bin" "$app/MacOS"
    ln -s ${lib.getExe cli} "$out/bin/${name}"
    cp "$infoPlistPath" "$app/Info.plist"
    makeBinaryWrapper ${lib.getExe cli} "$app/MacOS/${name}" --add-flags --notify
  ''
