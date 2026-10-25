# shellcheck shell=bash
# Body of battlenet-launcher. Loaded verbatim by ./package.nix via
# builtins.readFile into writeShellApplication, which sets $BATTLENET_PROTON
# (a Proton build's directory), $BATTLENET_DEFAULT_PREFIX, $BATTLENET_LOCALE
# and $BATTLENET_INSTALLER_URL, and puts curl and notify-send on PATH. It runs
# inside the FHS runtime (steam.buildRuntimeEnv), so Proton's prebuilt files
# find /lib64/ld-linux-x86-64.so.2 and python3.
#
# State lives outside the store:
#   $prefix               compat data (STEAM_COMPAT_DATA_PATH): pfx/ is the
#                         Wine prefix, version names the Proton that last
#                         upgraded it. Proton creates both on first use.
#   ~/.cache/battlenet/   the downloaded Battle.net-Setup.exe
#
# The environment is what umu-run hands Proton, minus its container. GE-Proton
# reads UMU_ID as "running without Steam" (it turns lsteamclient off) and
# STORE=battlenet as "simulate write-copy", which Battle.net needs.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: battlenet [COMMAND]

  (none)            start Battle.net, installing it first if it's missing
  install           download Blizzard's installer and run it
  run CMD [ARG...]  run a program in the prefix (winecfg, regedit, an .exe)
  kill              stop everything running in the prefix

BATTLENET_PREFIX overrides the configured prefix for one run.
EOF
}

prefix=${BATTLENET_PREFIX:-$BATTLENET_DEFAULT_PREFIX}
[[ $prefix == /* ]] || prefix=$HOME/$prefix
exe="$prefix/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"
setup=${XDG_CACHE_HOME:-$HOME/.cache}/battlenet/Battle.net-Setup.exe

export STEAM_COMPAT_DATA_PATH=$prefix
export STEAM_COMPAT_SHADER_PATH=$prefix/shadercache
# Proton reads this unguarded; empty means no Steam client DLLs to copy in.
export STEAM_COMPAT_CLIENT_INSTALL_PATH=""
export UMU_ID=umu-battlenet STORE=battlenet
export SteamAppId=battlenet SteamGameId=battlenet

say() {
  echo "battlenet: $1" >&2
  notify-send --app-name=Battle.net Battle.net "$1" 2>/dev/null || true
}

install_battlenet() {
  mkdir -p "$prefix" "${setup%/*}"
  say "Downloading the Battle.net installer"
  curl --fail --location --retry 3 --silent --show-error \
    --output "$setup.part" "$BATTLENET_INSTALLER_URL"
  mv "$setup.part" "$setup"
  # A new prefix is built before the installer opens, which takes a minute.
  say "Installing Battle.net in $prefix"
  STEAM_COMPAT_INSTALL_PATH=${setup%/*} "$BATTLENET_PROTON/proton" waitforexitandrun \
    "$setup" --lang="$BATTLENET_LOCALE" --installpath='C:\Program Files (x86)\Battle.net'
}

case ${1:-} in
  "")
    if [[ ! -f $exe ]]; then
      # The installer starts Battle.net when it finishes, so this run is done.
      install_battlenet
      exit
    fi
    STEAM_COMPAT_INSTALL_PATH=${exe%/*} exec "$BATTLENET_PROTON/proton" waitforexitandrun "$exe"
    ;;
  install)
    install_battlenet
    ;;
  run)
    shift
    if [[ $# -eq 0 ]]; then
      usage >&2
      exit 2
    fi
    mkdir -p "$prefix"
    exec "$BATTLENET_PROTON/proton" waitforexitandrun "$@"
    ;;
  kill)
    WINEPREFIX=$prefix/pfx exec "$BATTLENET_PROTON/files/bin/wineserver" -k
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
