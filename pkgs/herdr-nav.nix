# herdr-nav — vim-aware pane navigation for herdr; the herdr-side half of the
# nvim <C-h/j/k/l> integration (nvim side: config/multiplexer.lua). The
# implementation lives in ./herdr-nav.sh; this pins its runtime deps and runs
# ShellCheck over it via writeShellApplication.
#
# herdr is pinned rather than taken from PATH because this runs as a
# [[keys.command]] spawned by the herdr server, whose PATH we don't control.
{
  writeShellApplication,
  herdr,
  gnugrep,
  gnused,
  coreutils,
}:
writeShellApplication {
  name = "herdr-nav";
  runtimeInputs = [
    herdr
    gnugrep
    gnused
    coreutils
  ];
  text = builtins.readFile ./herdr-nav.sh;
}
