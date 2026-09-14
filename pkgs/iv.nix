{
  lib,
  buildGo127Module,
  fetchFromGitHub,
  pkg-config,
  resvg,
  vips,
  makeWrapper,
  zlib,
  bzip2,
  xz,
  zstd,
  fontconfig,
  freetype,
}:
# iv >= 0.15 needs go 1.27; nixpkgs' default buildGoModule is still 1.26
buildGo127Module rec {
  pname = "iv";
  version = "0.17.3";

  src = fetchFromGitHub {
    owner = "kenshaw";
    repo = "iv";
    rev = "v${version}";
    hash = "sha256-QnWb2VFIZCKMZjf74kWbWIV22qr76ivgTSZkWknppJk=";
  };

  # xo/magic and xo/blitz carry prebuilt static archives (libmagic/, libblitz/)
  # inside their modules; `go mod vendor` drops non-Go dirs, so keep the module cache.
  proxyVendor = true;
  vendorHash = "sha256-Hoxpk/z0as0OlX2F2JjonOvS0Ii3UDvwKVs1FWq2B0c=";

  buildInputs = [
    zlib
    bzip2
    xz
    zstd
    fontconfig
    freetype
    resvg
    vips
  ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.name=${pname}"
  ];

  trimpath = true;
  # decode tests render HTML/markdown through blitz, whose http client needs network
  doCheck = false;
  # env.CGO_LD_FLAGS = "-L ${resvg}/lib -lresvg";
  nativeBuildInputs = [
    pkg-config
    vips
    makeWrapper
  ];

  postFixup = ''
    wrapProgram $out/bin/${pname} \
      --set LD_LIBRARY_PATH ${resvg}/lib \
      --set DYLD_LIBRARY_PATH ${resvg}/lib
  '';
  meta = {
    description = "A command-line image viewer using terminal graphics";
    homepage = "https://github.com/kenshaw/iv";
    license = lib.licenses.mit;
    maintainers = [ { github = "kriswill"; } ];
  };
}
