_final: prev: {
  # build time 21m33s
  nodejs_24 = prev.nodejs_24.overrideAttrs {
    # tests are failing with 24.03
    # https://github.com/NixOS/nixpkgs/issues/423244
    doCheck = false;
  };
}
