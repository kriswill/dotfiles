{
  buildNpmPackage,
  fetchFromGitHub,
  bun,
  lib,
  ...
}:

buildNpmPackage rec {
  pname = "gh-actions-language-server";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "lttb";
    repo = pname;
    rev = "0287d3081d7b74fef88824ca3bd6e9a44323a54d";
    hash = "sha256-ZWO5G33FXGO57Zca5B5i8zaE8eFbBCrEtmwwR3m1Px4=";
  };

  postPatch = ''
    ln -s ${./package-lock.json} package-lock.json
  '';

  buildPhase = ''
    ${lib.getExe bun} ./build/node.ts
  '';

  npmDepsHash = "sha256-ChAJs3P0EKqZWid6OsQ5WZU/kQ1OUUPMUZc9/tM0VWQ=";
  npmBuildScript = "build:node";

  meta = {
    description = "GitHub Actions Language Server";
    homepage = "https://github.com/ittb/gh-actions-language-server";
    license = lib.licenses.mit;
  };
}
