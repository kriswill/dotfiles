# herdr-update-check: is any of our herdrs (the TUI fork, herdr-core,
# herdr-app) behind upstream, or running an older build than the one
# installed? Linux and macOS; see ./herdr-update-check.sh. The modules
# schedule it (services.herdr-update-check): a systemd user timer on NixOS, a
# launchd agent on nix-darwin. Defaults to the versions this flake pins.
{
  lib,
  stdenvNoCC,
  writeShellApplication,
  coreutils,
  curl,
  gnused,
  jq,
  libnotify,
  procps,
  systemd,
  xdg-utils,
  # The herdr-cli package's version: the base X.Y.Z of our fork's tag.
  cliVersion,
}:
let
  sources = lib.importJSON ../sources.json;
in
writeShellApplication {
  name = "herdr-update-check";
  runtimeInputs = [
    coreutils
    curl
    gnused
    jq
  ]
  # notify-send, busctl (waiting for a notification daemon), xdg-open, and ps
  # (a systemd user unit's PATH has no procps). macOS uses its own /bin/ps,
  # osascript and open.
  ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [
    libnotify
    procps
    systemd
    xdg-utils
  ];
  runtimeEnv = {
    HERDR_CLI_PINNED = cliVersion;
    HERDR_CORE_PINNED = sources.herdr-core.version;
    HERDR_APP_PINNED = sources.herdr-app.version;
  };
  text = builtins.readFile ./herdr-update-check.sh;
  meta = {
    description = "Report herdr, herdr-core and herdr-app releases newer than ours, and stale running builds";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "herdr-update-check";
  };
}
