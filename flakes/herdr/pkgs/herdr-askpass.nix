# herdr-askpass: SUDO_ASKPASS that asks in a dialog of the Herdr window showing
# the hc terminal, through a short-lived prompt terminal and the herdr-askpass
# Herdr mod; see ./herdr-askpass.sh. jq reads hc's JSON; procps is Linux's
# `ps` (macOS has /bin/ps). hc itself comes from PATH: it must be the one whose
# core runs the terminal.
{
  lib,
  stdenv,
  writeShellApplication,
  jq,
  procps,
}:
writeShellApplication {
  name = "herdr-askpass";
  runtimeInputs = [ jq ] ++ lib.optional stdenv.hostPlatform.isLinux procps;
  text = builtins.readFile ./herdr-askpass.sh;
  meta.description = "sudo askpass that asks in the Herdr window showing the hc terminal";
}
