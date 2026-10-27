{
  configurations.nixos.nebula.module = {
    # Daily vulnerability scan of the running system's runtime closure
    # (modules/nixos/nixploit.nix, from ./flakes/nixploit), with upstream's
    # recommended settings: NVD feed from 2002, kernel findings filtered
    # through the running kernel's Kbuild config (kbuild.enable defaults on).
    # OSV adds the PyPI/npm/crates.io/Go dumps plus GIT, whose commit ranges
    # turn history.enable on by default: commit-only upstream clones that
    # suppress findings already fixed in the installed release. Report:
    # /var/lib/nixploit/report.json, viewer: file:///var/lib/nixploit/report.html;
    # scan now: `sudo systemctl start nixploit`.
    services.nixploit = {
      enable = true;
      calendar = "daily";
      providers = [
        "nvd"
        "osv"
      ];
      # The HTML viewer with dependency analysis, readable by k without sudo.
      report = {
        enable = true;
        readers = [ "k" ];
      };
      # So the report follows each nrs that adds or drops a package.
      rescanOnSwitch = true;
      # Reviewed findings. The fingerprint pins each rule to the evidence it
      # was reviewed against; if that changes, the finding comes back.
      settings.ignore = [
        {
          package = "libmad";
          id = "CVE-2018-7263";
          bucket = "affected";
          fingerprint = "dc83a783dcf76d806dd88528d31515680108b17a35d51568f3d3cb6b7f934758";
          reason = "Misattributed: the double free is in the caller (mpg321; Debian traced the duplicate CVE-2017-11552 there, #870406). mpg321 is not installed; sox and VLC use libmad's low-level stream/frame/synth API and never call mad_decoder_run. Tenacity libmad 0.16.5 leaves decoder.c unchanged, so no upgrade fixes it.";
        }
      ];
    };

    # The module turns node_exporter on for its textfile metrics, listening on
    # 0.0.0.0:9100 by default. Nothing scrapes it off-host (the firewall keeps
    # it closed anyway), so keep it on loopback.
    services.prometheus.exporters.node.listenAddress = "127.0.0.1";
  };
}
