{
  configurations.nixos.nebula.module = {
    # Supervised codebase-memory-mcp daemon (systemd user service, HTTP graph UI
    # on :9749) + the cbm-ctl control CLI, from the kriswill/codebase-memory-mcp
    # fork's NixOS module (re-exported by modules/nixos/codebase-memory-mcp.nix).
    services.codebase-memory-mcp.enable = true;
  };
}
