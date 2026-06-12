{
  flake.modules.darwin.user-packages =
    {
      config,
      pkgs,
      ...
    }:
    {
      users.users.k.packages =
        (with pkgs; [
          age # encryption tool
          btop # resource monitor
          bun # batteries included typescript runtime
          comma # run programs without installing — github.com/nix-community/comma
          fd # file finding
          figlet # text to big fancy ASCII letters
          gnupg # signature verifier
          grc # generic text colorizer
          just # better make
          keycastr # keystroke visualizer
          localsend # share files over the local network
          ncdu # analyze disk usage
          nix-output-monitor # prettier nix build output
          nix-tree # browse nix store dependencies
          ripgrep # fast grep replacement
          sqlite-vec # sqlite vector-search extension
          tldr # simplified man pages
          tree # print directory trees
          uv # one python tool to rule them all!
        ])
        ++ [
          (pkgs.writeShellScriptBin "my-hello" ''
            echo "Hello, ${config.system.primaryUser}!"
          '')
        ];
    };
}
