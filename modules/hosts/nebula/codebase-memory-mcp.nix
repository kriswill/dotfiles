{
  configurations.nixos.nebula.module = {
    # Retain the fork/module for optional use, without installing its daemon or CLI.
    services.codebase-memory-mcp.enable = false;
  };
}
