{
  configurations.nixos.nebula.module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # The system's reference graph and generation membership, for the
      # viewer's "why it's here / what to do" analysis (./nixploit-report-graph.sh).
      reportGraph = pkgs.writeShellApplication {
        name = "nixploit-report-graph";
        runtimeInputs = [
          config.nix.package
          pkgs.coreutils
          pkgs.gnused
          pkgs.jq
        ];
        text = builtins.readFile ./nixploit-report-graph.sh;
      };

      # Browsers block fetch() from a file:// page, so a viewer next to
      # report.json can't load it. Render a copy of ./nixploit-report.html
      # with the report (and the graph, when collecting it works) embedded at
      # its marker line instead; open it directly as
      # /var/lib/nixploit/report.html. Escaping every `<` keeps the JSON
      # (where `<` only appears inside strings) from closing its script tag.
      # The graph is a separate program so its failure only drops the
      # analysis: errexit doesn't apply inside an `if` condition.
      renderHtml = pkgs.writeShellApplication {
        name = "nixploit-report-html";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnused
          reportGraph
        ];
        text = ''
          dir=''${1:-/var/lib/nixploit}
          report=$dir/report.json
          template=${./nixploit-report.html}
          [ -e "$report" ] || exit 0

          tmp=""
          work=$(mktemp -d)
          trap 'rm -rf "$work"; rm -f "$tmp"' EXIT
          if ! nixploit-report-graph >"$work/graph.json"; then
            echo "nixploit-report-html: no dependency graph, rendering without it" >&2
            : >"$work/graph.json"
          fi

          tmp=$(mktemp "$dir/.report.html.XXXXXX")
          {
            sed '/@NIXPLOIT_REPORT@/,$d' "$template"
            printf '<script id="report-meta" type="application/json">{"generated":"%s","host":"%s"}</script>\n' \
              "$(date -r "$report" --iso-8601=seconds)" "$(cat /proc/sys/kernel/hostname)"
            printf '<script id="report-data" type="application/json">'
            sed 's/</\\u003c/g' "$report"
            printf '</script>\n'
            if [ -s "$work/graph.json" ]; then
              printf '<script id="report-graph" type="application/json">'
              sed 's/</\\u003c/g' "$work/graph.json"
              printf '</script>\n'
            fi
            sed '1,/@NIXPLOIT_REPORT@/d' "$template"
          } >"$tmp"
          chmod 0640 "$tmp"
          mv -f "$tmp" "$dir/report.html"
        '';
      };
    in
    {
      # Daily vulnerability scan of the running system's runtime closure
      # (modules/nixos/nixploit.nix), with upstream's recommended settings: NVD
      # feed from 2002, kernel findings filtered through the running kernel's
      # Kbuild config (kbuild.enable defaults on). OSV adds the PyPI/npm/
      # crates.io/Go dumps plus GIT, whose commit ranges turn history.enable on
      # by default: commit-only upstream clones that suppress findings already
      # fixed in the installed release. Report: /var/lib/nixploit/report.json,
      # viewer: file:///var/lib/nixploit/report.html; scan now:
      # `sudo systemctl start nixploit`.
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

      # Let k read the report without sudo. Group membership alone isn't enough:
      # report.nu creates each report with `install --mode=0600`, so add group
      # read after every run, and render the HTML viewer (also 0640). A list
      # merges with the module's own ExecStopPost string (all run); `-` ignores
      # the failure before a first report exists.
      users.users.k.extraGroups = [ "nixploit" ];
      systemd.services.nixploit.serviceConfig.ExecStopPost = [
        "-${pkgs.coreutils}/bin/chmod g+r /var/lib/nixploit/report.json"
        "-${lib.getExe renderHtml}"
      ];
    };
}
