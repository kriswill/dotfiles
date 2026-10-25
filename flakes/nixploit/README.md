# nixploit

Wraps [nixploit](https://github.com/manic-systems/nixploit), a Nix vulnerability
scanner, for NixOS. It adds an HTML report step that explains, for every
vulnerable package, why it's on the system and what to do about it.

Upstream does the scanning: it lists the running system's runtime closure,
matches package versions against NVD (plus optional OSV and VulnCheck) data,
and writes `/var/lib/nixploit/report.json` on a systemd timer. This flake
re-exports upstream's package and NixOS module, and adds three options:

- `services.nixploit.report.enable` renders `/var/lib/nixploit/report.html`
  after every run.
- `services.nixploit.report.readers` lists the users who can read the reports
  without sudo.
- `services.nixploit.rescanOnSwitch` rescans after a switch that changes the
  installed packages.

## Files

| File | Purpose |
| --- | --- |
| [`flake.nix`](flake.nix) | flake-parts flake: packages and `nixosModules` for `x86_64-linux` and `aarch64-linux`. |
| [`nixos-module.nix`](nixos-module.nix) | Imports upstream's module and adds the `services.nixploit.report.*` and `rescanOnSwitch` options. |
| [`report.html`](report.html) | The viewer: one self-contained page, with no network access and a dark/light theme. |
| [`report.nix`](report.nix), [`report.sh`](report.sh) | `nixploit-report`: renders the viewer with a report embedded. |
| [`report-graph.nix`](report-graph.nix), [`report-graph.sh`](report-graph.sh) | `nixploit-report-graph`: the running system's dependency graph as JSON. |

## Flake outputs

- `packages.<system>.nixploit` is upstream's scanner (`default` points at it).
- `packages.<system>.nixploit-report` is the renderer: `nixploit-report [dir]`
  turns `<dir>/report.json` into `<dir>/report.html`. The default directory is
  `/var/lib/nixploit`.
- `packages.<system>.nixploit-report-graph` prints the dependency graph.
- `nixosModules.nixploit` (and `default`) is the module.

## The NixOS module

```nix
{ inputs, ... }:
{
  imports = [ inputs.nixploit.nixosModules.default ];

  services.nixploit = {
    enable = true;                  # upstream: daily feed update + scan
    providers = [ "nvd" "osv" ];    # upstream: OSV also turns on the history check
    report = {
      enable = true;                # render /var/lib/nixploit/report.html
      readers = [ "alice" ];        # nixploit group + group-readable report.json
    };
    rescanOnSwitch = true;          # rescan when a switch changes the packages
  };
}
```

All of upstream's `services.nixploit.*` options are unchanged; see
[upstream's README](https://github.com/manic-systems/nixploit#nixos). Our three
options:

- **`report.enable`** runs `nixploit-report` from the unit's `ExecStopPost`.
  The page it writes is `0640`, owned by `nixploit`.
- **`report.readers`** adds the listed users to the `nixploit` group. It also
  runs `chmod g+r` on `report.json` after every run, because upstream creates
  it `0600`. On a desktop whose systemd user manager survives logout, new
  membership only takes effect after a reboot. Until then,
  `sg nixploit -c 'cat /var/lib/nixploit/report.html'` works.
- **`rescanOnSwitch`** adds an `X-Packages` key to `nixploit.timer`: a hash of
  `system-path` and every user's `packages`. Upstream already rescans when the
  job config changes. Its timer carries the config's path as `X-Job`, a switch
  restarts any timer whose unit file changed, and the restarted timer fires
  after `OnActiveSec=2min` plus upstream's `RandomizedDelaySec=15min`, which
  applies to that trigger too. The new key extends that to package changes, so
  the report follows a switch (2 to 17 minutes later) instead of waiting for
  the next `calendar` run. A manual `systemctl start nixploit` in that window
  cancels the pending run.
  Changes outside those packages (a service's own package, say) still wait.
  The key can't follow the whole system, because the toplevel contains the
  timer unit.

All three only apply when `services.nixploit.enable` is set. Upstream's
`ExecStopPost` is a single string; ours are lists, and NixOS merges all of
them, so every entry runs. A `-` prefix keeps a missing first report from
failing the unit.

Not set here: the node_exporter that upstream's module enables listens on
`0.0.0.0:9100`. Bind it with
`services.prometheus.exporters.node.listenAddress` if nothing scrapes it from
another host.

## The report step

After every scan, `nixploit-report` copies `report.html` and embeds three
pieces of JSON at its marker line:

1. the report itself;
2. metadata (the host name and the report's modification time);
3. the graph from `nixploit-report-graph`.

The graph covers every store path in `/run/current-system`'s closure, with its
references from `nix path-info --recursive --json`, and records which system
generations hold each path. Every `<` is escaped as `\u003c`, so advisory text
can't close a script tag. The graph collector is a separate program, so if it
fails the page still renders, just without the analysis.

The data is embedded because browsers block `fetch()` from a `file://` page.
Opened on its own, without embedded data, `report.html` takes a `report.json`
by file picker or drag-and-drop. That mode has no dependency analysis.

For each vulnerable build, the viewer works out:

- **Who pulls it in.** It climbs the build's referrers up to the entries the
  system lists directly: packages (children of `system-path`), units (children
  of `system-units`/`user-units`, where a non-unit child comes from
  `systemd.packages`), `etc` entries, and the toplevel's own references.
  Restart-trigger nodes are skipped, because they reference everything.
- **Which package owns it.** Either the outermost package every route passes
  through (a dominator, such as an app's FHS runtime), or a consumer that all
  the other consumers depend on (Nix, for the tools and services built on it).
- **The shortest route** from the system, preferring the `system-path` branch.
- **Whether a fixed copy is already installed.** If the same package at a
  fixed version is also present, the vulnerable one is a separately pinned
  duplicate.
- **Which generations keep it.**

From these it writes rule-based **What to do** and **When it runs** advice and
groups findings in a **Causes** view. It reads the dependency structure only:
whether vulnerable code ever sees untrusted input is still the reader's call.
Dev shells and other GC roots aren't covered, because they're outside
upstream's `--system` scan.

## Consuming it from another flake

```nix
# parent flake.nix
inputs.nixploit = {
  url = "github:<owner>/<repo>?dir=flakes/nixploit";  # or "./flakes/nixploit" in-tree
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-parts.follows = "flake-parts";
};
```

`nixpkgs.follows` reaches upstream as well, because its input follows this
flake's nixpkgs. The scanner builds from source, since upstream has no binary
cache. Upstream's revision is pinned in this directory's `flake.lock`: run
`nix flake update upstream` here to move it. A parent that consumes this flake
by relative path picks up the change on its next evaluation; one that uses a
`github:` URL needs `nix flake update nixploit`.
