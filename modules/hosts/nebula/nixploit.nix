{
  configurations.nixos.nebula.module = {
    # Daily vulnerability scan of the running system's runtime closure
    # (modules/nixos/nixploit.nix), with upstream's recommended settings: NVD
    # feed from 2002, kernel findings filtered through the running kernel's
    # Kbuild config (kbuild.enable defaults on). OSV adds the PyPI/npm/
    # crates.io/Go dumps plus GIT, whose commit ranges turn history.enable on
    # by default: commit-only upstream clones that suppress findings already
    # fixed in the installed release. Report: /var/lib/nixploit/report.json;
    # scan now: `sudo systemctl start nixploit`.
    services.nixploit = {
      enable = true;
      calendar = "daily";
      providers = [
        "nvd"
        "osv"
      ];
    };

    # The module turns node_exporter on for its textfile metrics, listening on
    # 0.0.0.0:9100 by default. Nothing scrapes it off-host (the firewall keeps
    # it closed anyway), so keep it on loopback.
    services.prometheus.exporters.node.listenAddress = "127.0.0.1";
  };
}
