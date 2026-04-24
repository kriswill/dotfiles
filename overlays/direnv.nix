_final: prev: {
  # direnv's nixpkgs derivation sets doCheck = true, which runs the upstream
  # `make test-go test-bash test-fish test-zsh` suite during the build. The
  # zsh/bash/fish scenario tests occasionally hang indefinitely on aarch64-darwin
  # (0% CPU, no children, stuck in a pipe read), adding many minutes to any
  # rebuild whenever cache.nixos.org doesn't yet have a prebuilt direnv for our
  # nixpkgs rev. Skip checks locally — upstream + Hydra already run them.
  direnv = prev.direnv.overrideAttrs (_: { doCheck = false; });
}
