# The `kitten` that fastfetch finds first on its PATH (./package.nix puts it
# there). The script is ./kitten-shim.sh; this pins its one runtime
# dependency and runs ShellCheck over it via writeShellApplication. The real
# kitten is deliberately not pinned: the shim hands over to the next one on
# PATH, so each machine keeps whichever kitten it already has.
{
  writeShellApplication,
  coreutils,
}:
writeShellApplication {
  name = "kitten";
  runtimeInputs = [ coreutils ]; # stty
  text = builtins.readFile ./kitten-shim.sh;
}
