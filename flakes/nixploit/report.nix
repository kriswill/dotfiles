# nixploit-report: renders the HTML viewer (./report.html) with a nixploit
# report and the system's dependency graph embedded (./report.sh).
{
  writeShellApplication,
  coreutils,
  gnused,
  nixploit-report-graph,
}:
writeShellApplication {
  name = "nixploit-report";
  runtimeInputs = [
    coreutils
    gnused
    nixploit-report-graph
  ];
  runtimeEnv.NIXPLOIT_REPORT_TEMPLATE = "${./report.html}";
  text = builtins.readFile ./report.sh;
  meta.description = "Render a nixploit report as a standalone HTML page with dependency analysis";
}
