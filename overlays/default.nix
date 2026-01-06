{ inputs }: {
  claude-code = import ./claude-code.nix;
  kitten = import ./kitten.nix;
  opencode = import ./opencode.nix { inherit inputs; };
}
