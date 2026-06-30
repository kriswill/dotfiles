{
  lib,
  stdenv,
  git,
  codebase-memory-mcp,
}:
# cbm-tools — two tiny C programs that supervise and drive the
# codebase-memory-mcp daemon:
#   cbm-daemon  launchd-friendly foreground wrapper (holds stdin open via a FIFO)
#   cbm-ctl     control CLI (status / flush / commit / start|stop|restart / logs)
# Tool paths are baked in at compile time, so the binaries need nothing on PATH.
stdenv.mkDerivation {
  pname = "cbm-tools";
  inherit (codebase-memory-mcp) version;

  src = ./.;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    cc="''${CC:-cc}"
    cflags="-O2 -std=gnu11 -D_DARWIN_C_SOURCE -Wall -Wextra"

    $cc $cflags \
      -DCBM_BIN_DEFAULT='"${lib.getExe codebase-memory-mcp}"' \
      -o cbm-daemon cbm-daemon.c

    $cc $cflags \
      -DCBM_BIN='"${lib.getExe codebase-memory-mcp}"' \
      -DGIT='"${lib.getExe git}"' \
      -DLAUNCHCTL='"/bin/launchctl"' \
      -DLSOF='"/usr/sbin/lsof"' \
      -DTAIL='"/usr/bin/tail"' \
      -o cbm-ctl cbm-ctl.c

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 cbm-daemon $out/bin/cbm-daemon
    install -Dm755 cbm-ctl $out/bin/cbm-ctl
    runHook postInstall
  '';

  meta = {
    description = "Control CLI (cbm-ctl) and launchd daemon wrapper (cbm-daemon) for codebase-memory-mcp";
    mainProgram = "cbm-ctl";
    platforms = lib.platforms.darwin;
  };
}
