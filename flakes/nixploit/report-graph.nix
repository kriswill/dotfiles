# nixploit-report-graph: the running system's reference graph and generation
# membership as JSON, for the viewer's dependency analysis (./report-graph.sh).
# `nix` is the Nix the service talks to the daemon with; the NixOS module passes
# config.nix.package.
{
  writeShellApplication,
  coreutils,
  gnused,
  jq,
  nix,
}:
writeShellApplication {
  name = "nixploit-report-graph";
  runtimeInputs = [
    nix
    coreutils
    gnused
    jq
  ];
  text = builtins.readFile ./report-graph.sh;
  meta.description = "Print the running NixOS system's reference graph for the nixploit report viewer";
}
