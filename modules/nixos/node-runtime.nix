{
  flake.modules.nixos.node-runtime =
    # A JavaScript runtime on PATH (Node.js + Bun).
    #
    # NixOS ships no node by default, but several developer tools expect one to be
    # resolvable. In particular, Claude Code's MCP servers are launched via `npx`
    # (e.g. the chrome-devtools-mcp plugin runs `npx chrome-devtools-mcp@…`), so
    # without a node runtime on PATH those servers silently fail to start with
    # "npx: No such file or directory".
    #
    # `nodejs` provides `node`/`npm`/`npx`; `bun` is the user's preferred fast
    # runtime/package manager and doubles as an `npx`-compatible runner.
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.nodejs
        pkgs.bun
      ];
    }

  ;
}
