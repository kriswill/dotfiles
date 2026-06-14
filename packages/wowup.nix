# WowUp-CF (the CurseForge fork of WowUp), packaged from the upstream AppImage
# (github.com/WowUp/WowUp.CF releases).
#
# WowUp has no CLI flag or env var for the WoW install path — it only stores
# game locations in ~/.config/WowUpCf/, set through the GUI. So this wrapper
# can't *set* the path; instead, when `wowPath` is given it surfaces that WoW
# install at a clean, stable location (~/Games/World of Warcraft) and exports
# WOWUP_WOW_PATH, so you point WowUp at the tidy path once (Options -> "Add WoW")
# instead of digging into the Proton prefix. `--no-sandbox` is required for the
# bundled Electron/Chromium to launch on NixOS.
#
# Bump version/hash together; get the hash with:
#   nix store prefetch-file --hash-type sha256 \
#     https://github.com/WowUp/WowUp.CF/releases/download/v<version>/WowUp-CF-<version>.AppImage
{
  lib,
  appimageTools,
  fetchurl,
  writeScript,
  runtimeShell,
  # Absolute path to your WoW install dir (the folder that contains `_retail_`).
  # Leave null to wire nothing up and add the WoW folder by hand in the GUI.
  wowPath ? null,
}:
let
  pname = "wowup-cf";
  version = "2.22.0";

  src = fetchurl {
    url = "https://github.com/WowUp/WowUp.CF/releases/download/v${version}/WowUp-CF-${version}.AppImage";
    hash = "sha256-X5gDnj4YBZRBwJEeb8sVMNoGmWUI9iVdWOmsA20bWig=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };

  # Pre-launch shim placed in front of the real (FHS-wrapped) binary. It locates
  # its own directory at runtime, so it needn't bake in $out, then execs the
  # wrapped AppImage with --no-sandbox. When wowPath is set it also exports the
  # path and links it to a clean ~/Games location for the GUI to point at.
  launcher = writeScript pname ''
    #!${runtimeShell}
    ${lib.optionalString (wowPath != null) ''
      export WOWUP_WOW_PATH=${lib.escapeShellArg wowPath}
      mkdir -p "$HOME/Games"
      ln -sfn ${lib.escapeShellArg wowPath} "$HOME/Games/World of Warcraft"
    ''}here="$(dirname "$(readlink -f "$0")")"
    exec "$here/.${pname}-wrapped" --no-sandbox "$@"
  '';
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    # Desktop entry + icons so it shows up in the launcher. Point Exec at our
    # shim (which adds --no-sandbox itself, so drop it from the entry).
    install -Dm644 ${appimageContents}/${pname}.desktop \
      $out/share/applications/${pname}.desktop
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=${pname} %U'
    cp -r ${appimageContents}/usr/share/icons $out/share/

    # Slip the shim in front of the FHS launcher.
    mv $out/bin/${pname} $out/bin/.${pname}-wrapped
    install -Dm755 ${launcher} $out/bin/${pname}
  '';
}
