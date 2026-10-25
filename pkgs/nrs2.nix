{
  writeShellApplication,
  coreutils,
  dix,
  gawk,
  gnugrep,
  gnused,
  gzip,
  nix-output-monitor,
  xz,
  zstd,
}:
# nrs2 — prototype replacement for nrs (nh os switch on NixOS, nh darwin
# switch on the Macs), installed beside it for comparison. One script for both
# OSes, picked at runtime: nom build → dix diff → validate → the platform's
# activation, with output streamed and a state report on every exit. On NixOS
# the activation runs as a transient systemd unit (Ctrl-C detaches instead of
# killing it). Why: docs/nrs-pipeline.html (§14–15). Body: ./nrs2.sh.
#
# Deliberately NOT pinned (resolved from the ambient PATH): nix and nix-store
# (the system's own), sudo (the setuid wrapper), systemctl/systemd-run (the
# running systemd), and scutil (macOS).
writeShellApplication {
  name = "nrs2";
  runtimeInputs = [
    coreutils
    dix
    gawk
    gnugrep
    gnused
    # gzip/xz/zstd: unpacking the new kernel image for the reboot report
    gzip
    nix-output-monitor
    xz
    zstd
  ];
  text = builtins.readFile ./nrs2.sh;
}
