# pass-xdg — a drop-in `pass` (standard unix password manager) that defaults its
# store to an XDG-compliant location instead of the upstream default `~/.password-store`.
#
# pass reads PASSWORD_STORE_DIR from the environment; this wrapper exports it to
# $XDG_DATA_HOME/password-store (falling back to ~/.local/share/password-store
# when XDG_DATA_HOME is unset, per the XDG Base Directory spec) and then execs
# the real pkgs.pass by store path — so it's the same version, no recursion, and
# an explicitly-set PASSWORD_STORE_DIR in the caller's env still wins.
{
  writeShellApplication,
  pass,
}:
writeShellApplication {
  name = "pass";
  text = ''
    export PASSWORD_STORE_DIR="''${PASSWORD_STORE_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/password-store}"
    exec ${pass}/bin/pass "$@"
  '';
}
