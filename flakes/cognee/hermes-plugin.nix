{
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  wheel,
}:
buildPythonPackage {
  pname = "cognee-integration-hermes-agent";
  version = "1.4.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "topoteretes";
    repo = "cognee-integrations";
    rev = "2803f9c313ab5333471898cac08963c5998296c3";
    hash = "sha256-uFBaCtdEdBtvZMs5GxkTgU4jCRwrE7KGNT1C5I3W80c=";
  };
  sourceRoot = "source/integrations/hermes-agent";
  build-system = [
    setuptools
    wheel
  ];
}
