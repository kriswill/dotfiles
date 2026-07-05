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
          bat # cat(1) clone with syntax highlighting (aliased to `cat`)
          btop # resource monitor
          bun # batteries included typescript runtime
          comma # run programs without installing — github.com/nix-community/comma
          cppcheck # static analysis for C/C++
          fd # file finding
          figlet # text to big fancy ASCII letters
          fzf # fuzzy finder (keybindings/env in the stow zshrc)
          gnupg # signature verifier
          go # an awesome language
          grc # generic text colorizer
          jq # command-line JSON processor
          just # better make
          keycastr # keystroke visualizer
          lazygit # git TUI (aliased to `lg`)
          localsend # share files over the local network
          ncdu # analyze disk usage
          nix-index # locate the package providing a file (command-not-found db)
          nix-output-monitor # prettier nix build output
          nix-tree # browse nix store dependencies
          nodejs_24 # javascript runtime
          ripgrep # fast grep replacement
          rmpc # mpd terminal client
          sqlite-vec # sqlite vector-search extension
          tldr # simplified man pages
          tree # print directory trees
          uv # one python tool to rule them all!
          yamlfmt # format yaml
        ])
        ++ [
          (pkgs.writeShellScriptBin "my-hello" ''
            echo "Hello, ${config.system.primaryUser}!"
          '')
        ];
    };
}
