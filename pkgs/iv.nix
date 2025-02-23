{
  stdenv,
  lib,
  buildGoModule,
  fetchFromGitHub,
  pkg-config,
  resvg,
  vips,
  makeWrapper,
}:
buildGoModule rec {
  pname = "iv";
  version = "0.7.2";

  src = fetchFromGitHub {
    owner = "kenshaw";
    repo = "iv";
    rev = "v${version}";
    hash = "sha256-cdsyrtXWkOQKeq6FmVCNUdoFABJhy9FUaGVX4Akmjf4=";
  };

  vendorHash = "sha256-pNhDgv6l2qCmz+e0Kwd/AtYX6qfaZzfbtsKT/dC4300=";

  buildInputs = [ resvg vips ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.name=${pname}"
  ];

  trimpath = true;
  # env.CGO_LD_FLAGS = "-L ${resvg}/lib -lresvg";
  nativeBuildInputs = [ pkg-config vips makeWrapper ]; 

  postFixup = ''
    wrapProgram $out/bin/${pname} \
      --set LD_LIBRARY_PATH ${resvg}/lib \
      --set DYLD_LIBRARY_PATH ${resvg}/lib
  '';
  meta = {
    description = "A command-line image viewer using terminal graphics";
    homepage = "https://github.com/kenshaw/iv";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ kriswill ];
  };
}
