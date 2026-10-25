# battlenet: Blizzard's Battle.net launcher in a Proton prefix, without Steam
# or umu. ./battlenet.sh is the launcher. It runs inside nixpkgs' Steam FHS
# runtime (steam.buildRuntimeEnv, the builder behind steam-run and nixpkgs'
# umu-launcher), which provides the /lib64 loader and python3 that Proton's
# prebuilt files expect. Battle.net itself never enters the store: the
# launcher downloads Blizzard's installer on first run, and Battle.net updates
# itself from then on.
{
  lib,
  steam,
  writeShellApplication,
  makeDesktopItem,
  coreutils,
  curl,
  libnotify,
  proton-ge-bin,
  # A Proton build: a package with a `steamcompattool` output (proton-ge-bin)
  # or a package/store path holding a `proton` script.
  proton ? proton-ge-bin,
  # Compat data directory (STEAM_COMPAT_DATA_PATH); the Wine prefix is its
  # pfx/. A relative path is under the user's home.
  prefix ? "Games/battlenet",
  # Language for Blizzard's installer (--lang).
  locale ? "enUS",
  icon ? "applications-games",
  # Extra variables for Proton, e.g. { PROTON_ENABLE_WAYLAND = "1"; }.
  environment ? { },
}:
let
  protonDir = proton.steamcompattool or proton;
  protonName = proton.version or (lib.getName proton);

  launcher = writeShellApplication {
    name = "battlenet-launcher";
    runtimeInputs = [
      coreutils
      curl
      libnotify
    ];
    runtimeEnv = {
      BATTLENET_PROTON = "${protonDir}";
      BATTLENET_DEFAULT_PREFIX = prefix;
      BATTLENET_LOCALE = locale;
      BATTLENET_INSTALLER_URL = "https://downloader.battle.net/download/getInstaller?os=win&installer=Battle.net-Setup.exe";
    }
    // environment;
    text = builtins.readFile ./battlenet.sh;
  };

  desktopItem = makeDesktopItem {
    name = "battlenet";
    desktopName = "Battle.net";
    comment = "Blizzard's game launcher, in ${protonName}";
    exec = "battlenet";
    inherit icon;
    categories = [ "Game" ];
    startupNotify = true;
    actions.kill = {
      name = "Stop Battle.net and its games";
      exec = "battlenet kill";
    };
  };
in
steam.buildRuntimeEnv {
  pname = "battlenet";
  version = "0.1.0";
  runScript = lib.getExe launcher;
  # Wine processes outlive whatever started them: the installer starts
  # Battle.net and exits, Battle.net starts the games, and an app launcher may
  # spawn us through a parent that exits at once. bwrap's default
  # --die-with-parent would kill the sandbox then (nixpkgs' umu-launcher turns
  # it off for the same reason).
  dieWithParent = false;
  extraInstallCommands = ''
    ln -s ${desktopItem}/share $out/share
  '';
  passthru = { inherit launcher; };
  meta = {
    description = "Battle.net in ${protonName}, run directly in an FHS environment (no Steam, no umu)";
    homepage = "https://download.battle.net/";
    mainProgram = "battlenet";
    platforms = [ "x86_64-linux" ];
  };
}
