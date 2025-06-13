{
  self,
  outputs,
  inputs,
}:
let
  inherit (outputs) lib;
  inherit (inputs.darwin.lib) darwinSystem;
in
{
  # read a directory and return a list of all filenames inside except any default.nix
  # ripped from: https://github.com/EarthGman/nix-library/blob/main/lib/default.nix#L15
  autoImport =
    dir:
    let
      fileNames = builtins.attrNames (builtins.readDir dir);
      strippedFileNames = lib.filter (name: name != "default.nix") fileNames;
    in
    lib.forEach (strippedFileNames) (fileName: dir + /${fileName});

  mkHomeManager = path: username: {
    home-manager = {
      backupFileExtension = "backup";
      useUserPackages = true;
      useGlobalPkgs = true;
      users."${username}" = path;
      sharedModules = [ inputs.mac-app-util.homeManagerModules.default ];
      extraSpecialArgs = { inherit inputs username; };
    };
  };

  mkDarwin =
    hostmodule: username:
    darwinSystem {
      specialArgs = {
        inherit
          self
          inputs
          outputs
          lib
          ;
      };
      modules = [
        hostmodule
        inputs.home-manager.darwinModules.home-manager
        outputs.darwinModules
        (lib.mkHomeManager ../home username)
        { nixpkgs.hostPlatform = "aarch64-darwin"; }
      ];
    };
}
