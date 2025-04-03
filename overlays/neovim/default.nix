final: prev: {
  neovim-unwrapped = prev.neovim-unwrapped.overrideAttrs (drv: rec {
    version = "0.11.0";
    pname = "neovim-unwrapped";

    src = prev.fetchFromGitHub {
      owner = "neovim";
      repo = "neovim";
      rev = "93c55c238f4c1088da4dc6ec80103eb3ef4085d2";
      sha256 = "sha256-9P/MnFXp/US+dkJRpVwpVMG0pQk0GJbu2DybJNunP/s=";
    };
  });
}
