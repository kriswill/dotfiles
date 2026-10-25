{
  writeShellApplication,
  coreutils,
  dix,
  gawk,
  gnugrep,
  gnused,
  gzip,
  jq,
  nix-output-monitor,
  xz,
  zstd,
}:
# nrs — the rebuild helper on NixOS and nix-darwin. It replaced nh (nh os
# switch / nh darwin switch) on 2026-10-24 after running beside it as nrs2.
# One script for both OSes, picked at runtime: nom build → dix diff →
# validate → the platform's activation, with output streamed and a state
# report on every exit. On NixOS the activation runs as a transient systemd
# unit (Ctrl-C detaches instead of killing it). Manual:
# docs/nrs-pipeline.html. Body: ./nrs.sh.
#
# Deliberately NOT pinned (resolved from the ambient PATH): nix and nix-store
# (the system's own), sudo (the setuid wrapper), systemctl/systemd-run (the
# running systemd), and scutil (macOS).
writeShellApplication {
  name = "nrs";
  runtimeInputs = [
    coreutils
    dix
    gawk
    gnugrep
    gnused
    # gzip/xz/zstd: unpacking the new kernel image for the reboot report
    gzip
    # jq: parsing the restow's NDJSON activity events
    jq
    nix-output-monitor
    xz
    zstd
  ];
  text = builtins.readFile ./nrs.sh;
}
