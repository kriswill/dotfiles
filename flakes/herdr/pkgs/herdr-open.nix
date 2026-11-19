# herdr-open: $BROWSER that opens a link where you are looking at the terminal
# from, through a label on the hc terminal and the herdr-open Herdr mod; see
# ./herdr-open.sh. coreutils for millisecond `date` and fractional `sleep`
# (macOS's BSD tools have neither), jq to read the answer. hc itself comes from
# PATH: it must be the one whose core runs the terminal.
{
  writeShellApplication,
  coreutils,
  jq,
}:
writeShellApplication {
  name = "herdr-open";
  runtimeInputs = [
    coreutils
    jq
  ];
  text = builtins.readFile ./herdr-open.sh;
  meta.description = "Open a link in the browser of the machine whose Herdr window shows the hc terminal";
}
