# shellcheck shell=bash
# Body of battlenet-proton, the half of the launcher that runs inside the FHS
# runtime (steam.buildRuntimeEnv), where Proton's prebuilt files find
# /lib64/ld-linux-x86-64.so.2 and python3. Loaded verbatim by ./package.nix
# via builtins.readFile into writeShellApplication, which sets
# $BATTLENET_PROTON (a Proton build's directory), $BATTLENET_LOCALE and
# $BATTLENET_INSTALLER_URL, and puts curl, flock and notify-send on PATH.
# ./battlenet.sh decides what to run and passes the absolute prefix as
# $BATTLENET_PREFIX:
#
#   battlenet-proton install            download Blizzard's installer, run it
#   battlenet-proton VERB [ARG...]      run, waitforexitandrun or runinprefix
#
# The environment is what umu-run hands Proton, minus its container. GE-Proton
# reads UMU_ID as "running without Steam" (it turns lsteamclient off) and
# STORE=battlenet as "simulate write-copy", which Battle.net needs.
set -euo pipefail

prefix=${BATTLENET_PREFIX:?set by battlenet}
setup=${XDG_CACHE_HOME:-$HOME/.cache}/battlenet/Battle.net-Setup.exe
proton=$BATTLENET_PROTON/proton

export STEAM_COMPAT_DATA_PATH=$prefix
export STEAM_COMPAT_SHADER_PATH=$prefix/shadercache
# Proton reads this unguarded; empty means no Steam client DLLs to copy in.
export STEAM_COMPAT_CLIENT_INSTALL_PATH=""
export UMU_ID=umu-battlenet STORE=battlenet
export SteamAppId=battlenet SteamGameId=battlenet
# Xalia is Proton's gamepad navigation for launcher windows. Battle.net is
# driven by mouse, and Xalia floods stderr with TaskCanceledException traces
# while it tracks the window. PROTON_USE_XALIA=1 brings it back.
export PROTON_USE_XALIA=${PROTON_USE_XALIA:-0}

say() {
  echo "battlenet: $1" >&2
  notify-send --app-name=Battle.net Battle.net "$1" 2>/dev/null || true
}

install_battlenet() {
  mkdir -p "$prefix" "${setup%/*}"
  # Against a second click while the first install is still building the
  # prefix, before its wineserver exists for ./battlenet.sh to find.
  local lock_fd
  exec {lock_fd}>"${XDG_RUNTIME_DIR:-/tmp}/battlenet-$(printf '%s' "$prefix" | md5sum | cut -c1-16).lock"
  if ! flock --nonblock "$lock_fd"; then
    say "Battle.net is already being installed in $prefix"
    exit 1
  fi
  say "Downloading the Battle.net installer"
  curl --fail --location --retry 3 --silent --show-error \
    --output "$setup.part" "$BATTLENET_INSTALLER_URL"
  mv "$setup.part" "$setup"
  # A new prefix is built before the installer opens, which takes a minute.
  # Wine doesn't inherit the lock: its wineserver outlives the installer.
  say "Installing Battle.net in $prefix"
  STEAM_COMPAT_INSTALL_PATH=${setup%/*} "$proton" waitforexitandrun \
    "$setup" --lang="$BATTLENET_LOCALE" --installpath='C:\Program Files (x86)\Battle.net' \
    {lock_fd}>&-
}

case ${1:-} in
  install)
    install_battlenet
    ;;
  run | waitforexitandrun | runinprefix)
    mkdir -p "$prefix"
    exec "$proton" "$@"
    ;;
  *)
    echo "battlenet-proton: internal; use battlenet" >&2
    exit 2
    ;;
esac
