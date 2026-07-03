# codebase-memory-mcp launchd daemon, mounted into hosts k + SOC. The
# nix-darwin module ships in our kriswill/codebase-memory-mcp `nix` fork
# (nix/darwin/module.nix) and defaults services.codebase-memory-mcp.package to
# the fork's own package, so no overlay or pkgs wiring is needed. (The CLI
# package itself is on every host via core.nix's systemPackages.)
{ inputs, ... }:
let
  codebase-memory-mcp = {
    imports = [ inputs.codebase-memory-mcp.darwinModules.codebase-memory-mcp ];
    services.codebase-memory-mcp.enable = true;
  };
in
{
  configurations.darwin.k.module = codebase-memory-mcp;
  configurations.darwin.SOC-Kris-Williams.module = codebase-memory-mcp;
}
