#!/usr/bin/env bash
# git-signing-agent loader: the launchd daemon behind services.git-signing-agent
# (./default.nix has the design). Runs as root and:
#
#   1. starts an ssh-agent as $GSA_USER on $GSA_SOCKET_DIR/agent.sock
#   2. reads the signing key from 1Password with a service-account token
#      (root-only sops secret) and pipes it straight into that agent with
#      ssh-add, so the key is never written to disk
#   3. checks that the loaded key is the configured public key
#   4. waits on the agent; when the agent dies this script exits and launchd
#      (KeepAlive) starts the whole thing again
#
# ssh-agent accepts connections from its own uid and from root, so the agent
# runs as the user and root loads it. The user's processes (git, a Claude
# session) can ask for signatures through the socket, but can't read the
# token (0400 root) or the key (ssh-agent memory).
#
# Configured entirely through the environment (set by the launchd plist), so
# the script runs outside launchd for testing. When not run as root it starts
# the agent directly instead of via sudo.
set -euo pipefail

: "${GSA_USER:?}" "${GSA_SOCKET_DIR:?}" "${GSA_TOKEN_FILE:?}" "${GSA_OP_ITEM:?}"
: "${GSA_PUBLIC_KEY:?}" "${GSA_OP:?}"
SSH_AGENT=${GSA_SSH_AGENT:-/usr/bin/ssh-agent}
SSH_ADD=${GSA_SSH_ADD:-/usr/bin/ssh-add}
MAX_BACKOFF=${GSA_MAX_BACKOFF:-300}
SOCK="$GSA_SOCKET_DIR/agent.sock"

log() { printf '%s git-signing-agent: %s (loader elapsed=%ss)\n' "$(/bin/date '+%Y-%m-%dT%H:%M:%S%z')" "$*" "$SECONDS"; }

log "loader entered"

agent_pid=""
# shellcheck disable=SC2329 # invoked by the EXIT trap
cleanup() {
  if [ -n "$agent_pid" ]; then kill "$agent_pid" 2>/dev/null || true; fi
  rm -f "$SOCK"
}
trap cleanup EXIT
# launchd stops a job with SIGTERM. Sleeps and waits below run as
# `cmd & wait`, so the trap fires at once rather than after the sleep.
trap 'log "stopping"; exit 0' TERM INT

pause() {
  sleep "$1" &
  wait $! || true
}

# Type and base64 only: the configured key and `ssh-add -L` differ in comment.
key_id() { awk '{ print $1 " " $2 }'; }
WANT=$(printf '%s\n' "$GSA_PUBLIC_KEY" | key_id)

# --- 1. the agent -----------------------------------------------------------
mkdir -p "$GSA_SOCKET_DIR"
chown "$GSA_USER:$(id -g "$GSA_USER")" "$GSA_SOCKET_DIR"
chmod 0700 "$GSA_SOCKET_DIR"
rm -f "$SOCK"

log "starting ssh-agent as $GSA_USER"
if [ "$(id -u)" -eq 0 ] && [ "$GSA_USER" != root ]; then
  /usr/bin/sudo -u "$GSA_USER" -- "$SSH_AGENT" -D -a "$SOCK" >/dev/null &
else
  "$SSH_AGENT" -D -a "$SOCK" >/dev/null &
fi
agent_pid=$!

for _ in $(seq 50); do
  [ -S "$SOCK" ] && break
  kill -0 "$agent_pid" 2>/dev/null || { log "ssh-agent exited at startup"; exit 1; }
  pause 0.2
done
[ -S "$SOCK" ] || { log "ssh-agent never created $SOCK"; exit 1; }
log "ssh-agent (pid $agent_pid) listening on $SOCK"

# --- 2+3. the key -------------------------------------------------------------
load_key() {
  local err have
  log "loading signing key"
  # The token reaches op only through its environment, never argv. The
  # private key goes from op's stdout into ssh-add's stdin. Only the stderr
  # of the two (error text, no secrets) is captured, for the log.
  if ! err=$({
    OP_SERVICE_ACCOUNT_TOKEN=$(<"$GSA_TOKEN_FILE") \
      "$GSA_OP" read "op://${GSA_OP_ITEM}/private key?ssh-format=openssh" |
      SSH_AUTH_SOCK="$SOCK" "$SSH_ADD" -q -
  } 2>&1 >/dev/null); then
    log "could not load op://${GSA_OP_ITEM}: $(printf '%s' "$err" | tr '\n' ' ')"
    return 1
  fi
  have=$(SSH_AUTH_SOCK="$SOCK" "$SSH_ADD" -L | key_id)
  if [ "$have" != "$WANT" ]; then
    SSH_AUTH_SOCK="$SOCK" "$SSH_ADD" -D >/dev/null 2>&1 || true
    log "op://${GSA_OP_ITEM} is not the configured publicKey; unloaded it." \
      "Loaded: ${have:-nothing}. Expected: $WANT"
    return 1
  fi
}

delay=$((MAX_BACKOFF < 5 ? MAX_BACKOFF : 5))
while :; do
  kill -0 "$agent_pid" 2>/dev/null || { log "ssh-agent exited"; exit 1; }
  if [ ! -s "$GSA_TOKEN_FILE" ]; then
    log "waiting for $GSA_TOKEN_FILE (decrypted by sops-install-secrets)"
  elif load_key; then
    break
  fi
  log "retrying in ${delay}s"
  pause "$delay"
  delay=$((delay * 2 > MAX_BACKOFF ? MAX_BACKOFF : delay * 2))
done

log "signing key loaded: $(SSH_AUTH_SOCK="$SOCK" "$SSH_ADD" -l)"

# --- 4. stay with the agent ---------------------------------------------------
status=0
wait "$agent_pid" || status=$?
agent_pid=""
log "ssh-agent exited (status $status); launchd will restart"
exit 1
