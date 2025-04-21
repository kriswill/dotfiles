{ inputs, lib }:
{
  # read a directory and return a list of all filenames inside
  autoImport = dir: lib.forEach (builtins.attrNames (builtins.readDir dir)) (dirname: dir + /${dirname});

  mkHomeManager = path: username: {
    home-manager = {
      useUserPackages = true;
      useGlobalPkgs = true;
      users."${username}" = path;
      sharedModules = [ inputs.mac-app-util.homeManagerModules.default ];
      extraSpecialArgs = { inherit inputs username; };
    };
  };
}
