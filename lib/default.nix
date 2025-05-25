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
  # # read a directory and return a list of all filenames inside
  # autoImport =
  #   dir: lib.forEach (builtins.attrNames (builtins.readDir dir)) (dirname: dir + /${dirname});

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
