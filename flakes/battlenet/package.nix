# battlenet: Blizzard's Battle.net launcher in a Proton prefix, without Steam
# or umu. Two halves:
#
#   battlenet (./battlenet.sh) runs on the host. It finds the prefix's
#     wineserver in any sandbox, joins or refuses, and does `kill`. It can't
#     run in the sandbox, where bwrap's user namespace hides other processes'
#     cwd and environ.
#   battlenet-proton (./battlenet-proton.sh) runs inside nixpkgs' Steam FHS
#     runtime (steam.buildRuntimeEnv, the builder behind steam-run and nixpkgs'
#     umu-launcher), which provides the /lib64 loader and python3 that Proton's
#     prebuilt files expect. It sets Proton's environment, installs, and runs
#     the Proton verb battlenet picked.
#
# Battle.net itself never enters the store: the launcher downloads Blizzard's
# installer on first run, and Battle.net updates itself from then on.
{
  lib,
  steam,
  runCommand,
  symlinkJoin,
  writeShellApplication,
  makeDesktopItem,
  coreutils,
  curl,
  libnotify,
  procps,
  util-linux,
  proton-ge-bin,
  # A Proton build: a package with a `steamcompattool` output (proton-ge-bin)
  # or a package/store path holding a `proton` script.
  proton ? proton-ge-bin,
  # Compat data directory (STEAM_COMPAT_DATA_PATH); the Wine prefix is its
  # pfx/. A relative path is under the user's home; null means
  # $XDG_DATA_HOME/battlenet (~/.local/share/battlenet), resolved at run time.
  prefix ? null,
  # CPUs the whole session (Battle.net, WoW, Proton, the wineserver) runs on,
  # as a `taskset -c` list such as "0-5,12-17"; null leaves affinity alone.
  cpus ? null,
  # Language for Blizzard's installer (--lang).
  locale ? "enUS",
  icon ? "applications-games",
  # Extra variables for Proton, e.g. { PROTON_ENABLE_WAYLAND = "1"; }.
  environment ? { },
}:
let
  version = "0.1.0";
  protonName = proton.version or (lib.getName proton);

  # GE-Proton bundles an old libxkbcommon (newest version tag V_1.9.0) and puts
  # its own lib directories first on LD_LIBRARY_PATH. Inside Valve's runtime
  # that copy matches everything else; in this FHS it shadows nixpkgs'
  # libxkbcommon, and nixpkgs' SDL3 needs V_1.10.0. SDL3 failed to load
  # ("Failed loading SDL3 library." from sdl2-compat), so Wine's winebus ran
  # without its SDL game-controller backend. This is the Proton tree with the
  # bundled libxkbcommon and libxkbregistry left out, so the FHS's nixpkgs
  # copies load: they keep every older version tag. Only the directories on
  # the way to those libraries are real; everything else is a symlink to the
  # original. Proton copies symlinks in files/share/default_pfx as symlinks
  # when it builds a prefix, so linking the files one by one there would put
  # store links into new prefixes.
  protonDir = runCommand "${protonName}-battlenet" { } ''
    shopt -s dotglob
    src=${proton.steamcompattool or proton}
    mirror() {
      mkdir -p "$out''${1:+/$1}"
      for entry in "$src''${1:+/$1}"/*; do
        ln -s "$entry" "$out''${1:+/$1}/"
      done
    }
    mirror ""
    for dir in files files/lib files/lib/x86_64-linux-gnu files/lib/i386-linux-gnu; do
      rm "$out/$dir"
      mirror "$dir"
    done
    rm "$out"/files/lib/{x86_64,i386}-linux-gnu/libxkb{common,registry}.so*
  '';

  inner = writeShellApplication {
    name = "battlenet-proton";
    runtimeInputs = [
      coreutils
      curl
      libnotify
      util-linux
    ];
    runtimeEnv = {
      BATTLENET_PROTON = "${protonDir}";
      BATTLENET_LOCALE = locale;
      BATTLENET_INSTALLER_URL = "https://downloader.battle.net/download/getInstaller?os=win&installer=Battle.net-Setup.exe";
    };
    # `environment` sets defaults rather than runtimeEnv's unconditional
    # exports, so a variable set for one run wins, e.g.
    # `PROTON_ENABLE_WAYLAND=0 battlenet` to try XWayland again.
    text =
      lib.concatStrings (
        lib.mapAttrsToList (name: value: ''
          : "''${${name}=${lib.escapeShellArg value}}"
          export ${name}
        '') environment
      )
      + builtins.readFile ./battlenet-proton.sh;
  };

  fhs = steam.buildRuntimeEnv {
    pname = "battlenet-proton";
    inherit version;
    runScript = lib.getExe inner;
    # Steam's FHS library set assumes Valve's runtime container supplies the
    # rest. Without it, Wine's unix modules dlopen these from the FHS, in both
    # widths: GE-Proton 11 still ships i386-unix, and Blizzard's installer is a
    # 32-bit program (without 32-bit FreeType it can't render text). Everything
    # Wine's unix modules name is then present except libodbc and libpcsclite
    # (databases, smart cards).
    extraLibraries =
      pkgs: with pkgs; [
        freetype
        fontconfig
        # Replaces Proton's bundled copy (see protonDir); also needed by SDL3.
        libxkbcommon
        libxcomposite
        libxcursor
        libxi
        libxinerama
        libxrandr
        libxrender
        libxxf86vm
        alsa-lib
        libpulseaudio
        SDL2
        libgcrypt
        # Proton's bundled ffmpeg (libavutil) links libvdpau. Without it the
        # whole ffmpeg stack fails to load, and so does winedmo, Wine's
        # ffmpeg-based Media Foundation demuxer and decoder.
        libvdpau
      ];
    # Wine finds a prefix's wineserver through a socket under /tmp/.wine-$UID.
    # With buildRuntimeEnv's default private /tmp, every invocation started its
    # own wineserver on the same prefix: `battlenet kill` and `battlenet run`
    # couldn't reach the running one, a second launch started a second
    # Battle.net, and two servers wrote one registry. nixpkgs' heroic shares
    # /tmp for the same builder too.
    privateTmp = false;
    # Wine processes outlive whatever started them: the installer starts
    # Battle.net and exits, Battle.net starts the games, and an app launcher
    # may spawn us through a parent that exits at once. bwrap's default
    # --die-with-parent would kill the sandbox then (nixpkgs' umu-launcher
    # turns it off for the same reason).
    dieWithParent = false;
  };

  launcher = writeShellApplication {
    name = "battlenet";
    runtimeInputs = [
      coreutils
      libnotify
      procps
      util-linux
    ];
    runtimeEnv = {
      BATTLENET_FHS = lib.getExe fhs;
      BATTLENET_DEFAULT_PREFIX = if prefix == null then "" else prefix;
      BATTLENET_DEFAULT_CPUS = if cpus == null then "" else cpus;
    };
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
symlinkJoin {
  name = "battlenet-${version}";
  paths = [
    launcher
    desktopItem
  ];
  passthru = { inherit fhs inner launcher; };
  meta = {
    description = "Battle.net in ${protonName}, run directly in an FHS environment (no Steam, no umu)";
    homepage = "https://download.battle.net/";
    mainProgram = "battlenet";
    platforms = [ "x86_64-linux" ];
  };
}
