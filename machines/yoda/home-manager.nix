{
  imports = [ ../../home ];

  home = rec {
    username = "k";
    homeDirectory = "/home/${username}";
  };
}
