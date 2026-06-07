{
  pkgs,
  lib,
  config,
  ...
}:
{
  # example for merging your shared config
  config = lib.mkMerge [
    # {
    #	  your-name-here.your-module-1.enable = true;
    #	  your-name-here.your-module-2.enable = true;
    #	  # more module boilerplate here
    #	  ...
    #	}

    #	You can also define and enable modules only if a certain condition is met
    #	(lib.mkIf (some condition here) {
    #	  your-name-here.module-3.enable = true;
    #	  # any other modules
    #	  ...
    # })
  ];
}
