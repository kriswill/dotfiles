# nix/darwinSandbox.nix — the macOS sandbox every Hermes process starts in
#
# Ours: not an upstream file. Upstream's only isolation on macOS is the
# `docker` terminal backend, which confines the commands the agent runs but
# not the agent, and needs a container runtime. This confines the whole
# process tree with Seatbelt (`sandbox-exec`, the mechanism nix, Chromium and
# the other agent CLIs use), which the kernel enforces on every descendant:
# a sandboxed process cannot leave, and cannot start another sandbox.
#
# The profile is deny-by-default. What it grants:
#
#   read          the system (/nix, /usr, /System, /Library, /etc, ...), and
#                 `readPaths`
#   read + write  `stateDir` (HERMES_HOME, the workspace, and HOME for
#                 everything inside), a private TMPDIR, and `readWritePaths`
#   network       IP in both directions on loopback and out anywhere; unix
#                 sockets only inside the writable paths, plus DNS, syslog
#                 and `unixSockets`
#   mach          name lookup, DNS, TLS trust evaluation, logging
#
# What that leaves out, each checked on macOS 26.4 (README, "The sandbox"):
# the real home (ssh keys, dotfiles, browser profiles, the 1Password agent
# socket), other programs' temp files and sockets (tmux, herdr), the
# keychain, the pasteboard, Apple events, LaunchServices (`open`), launchd
# job submission, setuid programs (sudo), `defaults write`.
#
# Paths must be canonical: Seatbelt matches the resolved path, so a symlink
# into an allowed directory is judged by its target.
{ lib, pkgs }:
{
  stateDir,
  workingDirectory,
  readPaths ? [ ],
  readWritePaths ? [ ],
  unixSockets ? [ ],
  passEnvironment ? [ ],
  extraProfile ? "",
}:
let
  quote = p: ''"${lib.escape [ ''"'' "\\" ] p}"'';
  subpaths = ps: lib.concatMapStringsSep "\n  " (p: "(subpath ${quote p})") ps;
  literals = ps: lib.concatMapStringsSep "\n  " (p: "(literal ${quote p})") ps;

  writable = [ stateDir ] ++ readWritePaths;

  profile = pkgs.writeText "hermes-agent.sb" ''
    (version 1)
    (deny default)

    ; ── processes ────────────────────────────────────────────────────────
    ; Any program may run, but setuid ones lose their privilege and fail.
    (allow process-exec*)
    (allow process-fork)
    (allow signal (target same-sandbox))
    (allow process-info* (target same-sandbox))
    (allow process-info-pidinfo)
    (allow process-info-setcontrol (target self))
    (allow sysctl-read)
    (allow ipc-posix-sem)
    (allow ipc-posix-shm-read*
      (ipc-posix-name-prefix "apple.shm.notification_center")
      (ipc-posix-name-prefix "apple.cfprefs."))
    (allow pseudo-tty)

    ; ── read: the system ─────────────────────────────────────────────────
    ; Metadata everywhere, so realpath() and stat() work on the way to an
    ; allowed path. It names nothing: listing a directory is a data read.
    (allow file-read-metadata)
    (allow file-read*
      (literal "/")
      (literal "/Users")
      (literal "/private")
      (literal "/private/var")
      (subpath "/nix")
      (subpath "/usr")
      (subpath "/bin")
      (subpath "/sbin")
      (subpath "/opt")
      (subpath "/System")
      (subpath "/Library")
      (subpath "/Applications")
      (subpath "/private/etc")
      (subpath "/private/var/db")
      (subpath "/private/var/run")
      (subpath "/private/var/select")
      (subpath "/dev")
      ${subpaths readPaths})

    ; sops-nix's decrypted secrets live under /run.
    (deny file-read*
      (subpath "/private/var/run/secrets")
      (subpath "/private/var/run/secrets.d"))

    ; ── read + write: the state directory, the private temp ──────────────
    ; Xcode's /usr/bin shims (git, python3, cc) cache their tool lookup in
    ; the real temp directory, not TMPDIR, and complain on every run without.
    (allow file-read* file-write*
      (regex #"^/private/var/folders/[^/]+/[^/]+/T/xcrun_db"))
    (allow file-read* file-write*
      (subpath (param "TMP_DIR"))
      ${subpaths writable})
    (allow file-write-data file-ioctl
      (literal "/dev/null")
      (literal "/dev/zero")
      (literal "/dev/tty")
      (literal "/dev/ptmx")
      (literal "/dev/dtracehelper")
      (regex #"^/dev/ttys[0-9]+$")
      (regex #"^/dev/fd/[0-9]+$"))
    (allow file-ioctl (literal "/dev/urandom") (literal "/dev/random"))

    ; ── network ──────────────────────────────────────────────────────────
    (allow network-outbound (remote ip))
    (allow network-inbound (local ip "localhost:*"))
    (allow network-bind (local ip "localhost:*"))
    (allow system-socket)
    ; A unix socket is a way into whatever serves it (a tmux or herdr server,
    ; an ssh agent), so only Hermes's own and the listed ones.
    (allow network*
      (subpath (param "TMP_DIR"))
      ${subpaths writable})
    (allow network-outbound
      (literal "/private/var/run/mDNSResponder")
      (literal "/private/var/run/syslog")
      ${literals unixSockets})

    ; ── system services: name lookup, DNS, TLS trust, logging ────────────
    (allow mach-lookup
      (global-name "com.apple.system.opendirectoryd.libinfo")
      (global-name "com.apple.system.opendirectoryd.membership")
      (global-name "com.apple.system.notification_center")
      (global-name "com.apple.system.logger")
      (global-name "com.apple.logd")
      (global-name "com.apple.diagnosticd")
      (global-name "com.apple.dnssd.service")
      (global-name "com.apple.SystemConfiguration.configd")
      (global-name "com.apple.SystemConfiguration.DNSConfiguration")
      (global-name "com.apple.trustd.agent")
      (global-name "com.apple.trustd")
      (global-name "com.apple.bsd.dirhelper")
      (global-name "com.apple.FSEvents")
      (global-name "com.apple.cfprefsd.daemon")
      (global-name "com.apple.cfprefsd.agent"))
    (allow user-preference-read)

    ${extraProfile}
  '';

  # Variables that cross into the sandbox. Everything else in the caller's
  # environment stays out: a shell's tokens are not the agent's to read.
  passNames = [
    "TERM"
    "TERMINFO"
    "TERMINFO_DIRS"
    "COLORTERM"
    "TERM_PROGRAM"
    "TERM_PROGRAM_VERSION"
    "COLUMNS"
    "LINES"
    "NO_COLOR"
    "FORCE_COLOR"
    "LANG"
    "TZ"
    "USER"
    "LOGNAME"
    "SHELL"
    "NIX_SSL_CERT_FILE"
    "SSL_CERT_FILE"
    "XPC_FLAGS"
    "XPC_SERVICE_NAME"
    "__CF_USER_TEXT_ENCODING"
    "__NIX_DARWIN_SET_ENVIRONMENT_DONE"
  ]
  ++ passEnvironment;
  passPrefixes = [
    "HERMES_"
    "LC_"
    # The Herdr pane the CLI runs in (hermesCli.nix).
    "HERDR_"
    "HC_"
  ];

  launcher = pkgs.writeShellScript "hermes-sandbox" ''
    set -euo pipefail

    # Already inside (the gateway or a terminal tool running `hermes`): the
    # sandbox is inherited, and applying one again is refused by the kernel.
    if [ -n "''${HERMES_SANDBOX:-}" ]; then
      exec "$@"
    fi

    state=${lib.escapeShellArg stateDir}
    tmp="$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)hermes-agent"
    /bin/mkdir -p -m 700 "$tmp" "$state"
    tmp="$(cd "$tmp" && pwd -P)"

    # /bin/ps is setuid, which the sandbox refuses, and Hermes identifies
    # gateway processes with `ps`: nixpkgs' unprivileged build goes first.
    env=(HOME="$state" TMPDIR="$tmp/" HERMES_SANDBOX=1 PATH="${pkgs.ps}/bin:''${PATH:-/usr/bin:/bin}")
    while IFS= read -r name; do
      case "$name" in
        HOME|TMPDIR|HERMES_SANDBOX|PATH) continue ;;
        ${lib.concatStringsSep "|" (passNames ++ map (p: p + "*") passPrefixes)})
          env+=("$name=''${!name}") ;;
      esac
    done < <(/usr/bin/awk 'BEGIN { for (name in ENVIRON) print name }')

    # A working directory the sandbox cannot read breaks getcwd() in every
    # child. Start in the workspace instead, and say so.
    here="$(pwd -P 2>/dev/null || true)"
    inside=
    for root in "$tmp" ${lib.escapeShellArgs (writable ++ readPaths)}; do
      case "$here/" in "$root"/*) inside=1 ;; esac
    done
    if [ -z "$inside" ]; then
      if [ -t 2 ]; then
        echo "hermes: $here is outside the sandbox; starting in ${workingDirectory}" >&2
      fi
      /bin/mkdir -p ${lib.escapeShellArg workingDirectory}
      cd ${lib.escapeShellArg workingDirectory}
    fi

    exec /usr/bin/env -i "''${env[@]}" \
      /usr/bin/sandbox-exec -f ${profile} -D TMP_DIR="$tmp" "$@"
  '';
in
{
  inherit launcher profile;
}
