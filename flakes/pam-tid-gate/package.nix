# pam-tid-gate: Touch ID for sudo only while someone can reach this Mac's own
# Touch ID readers; otherwise sudo goes straight to the password. Builds a PAM
# module (lib/pam/pam_tid_gate.so) that stands in for pam_tid.so in
# /etc/pam.d/sudo_local, and a CLI (bin/pam-tid-gate) that prints the decision.
{
  lib,
  stdenv,
  openpam,
}:
stdenv.mkDerivation {
  pname = "pam-tid-gate";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./pam_tid_gate.c
      ./pam-tid-gate.c
    ];
  };

  strictDeps = true;
  # Headers only. Neither binary links libpam: sudo's own (system) libpam must
  # be the only one in the process, since pam_tid gets its handle.
  buildInputs = [ openpam ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -Wextra -Werror -bundle -o pam_tid_gate.so pam_tid_gate.c \
      -framework IOKit -framework CoreFoundation
    $CC -O2 -Wall -Wextra -Werror -o pam-tid-gate pam-tid-gate.c \
      -DMODULE_PATH="\"$out/lib/pam/pam_tid_gate.so\""
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 pam_tid_gate.so $out/lib/pam/pam_tid_gate.so
    install -Dm555 pam-tid-gate $out/bin/pam-tid-gate
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    if otool -L $out/lib/pam/pam_tid_gate.so | grep -q libpam; then
      echo "pam_tid_gate.so must not link a libpam" >&2
      exit 1
    fi
    if nm -u $out/lib/pam/pam_tid_gate.so | grep -q '^_pam_'; then
      echo "pam_tid_gate.so must not call libpam" >&2
      exit 1
    fi
    nm -gU $out/lib/pam/pam_tid_gate.so | grep -q ' _pam_sm_authenticate$'
    nm -gU $out/lib/pam/pam_tid_gate.so | grep -q ' _pam_tid_gate_explain$'
    runHook postInstallCheck
  '';

  meta = {
    description = "Touch ID for sudo only while someone can reach this Mac's own readers";
    platforms = lib.platforms.darwin;
    mainProgram = "pam-tid-gate";
  };
}
