// Scaffold pass: custom packages (pkgs/), overlay-only entries (no pkgs/
// counterpart), and sub-flakes (flakes/) -> knowledge/packages/<name>.md.

import type { ScaffoldContext } from "./okf-scaffold-api";
import type { Repo } from "./lib";

export function scaffoldPackages(ctx: ScaffoldContext, repo: Repo): void {
  const { emit, titleFromSlug, sentence, firstSentence, mdSafe, firstMatch } = ctx;
  const gitISO = ctx.timestamp;

  /** Leading `# …` comment block at the top of a .nix file, joined. */
  const leadingComment = (src: string) => ctx.leadingComment(src, "#");

  console.log("packages:");
  const pkgNames = new Set<string>();
  for (const entry of repo.nixFiles("pkgs").filter((f) => f.endsWith(".nix"))) {
    const name = entry.replace(/\.nix$/, "");
    pkgNames.add(name);
    const srcRel = `pkgs/${entry}`;
    const src = repo.read(srcRel);
    const desc =
      firstMatch(src, /description\s*=\s*"([^"]+)"/) ??
      leadingComment(src) ??
      `Custom Nix package '${name}'`;
    const version = firstMatch(src, /version\s*=\s*"([^"]+)"/);
    const overlay = repo.exists(`overlays/${name}.nix`) ? `overlays/${name}.nix` : null;

    const lines = [
      mdSafe(sentence(desc)),
      "",
      `Added per the [add-package playbook](../playbooks/add-package.md).`,
      "",
      "## Source",
      "",
      `- Package: [\`${srcRel}\`](../../${srcRel})`,
    ];
    if (version) lines.push(`- Version at last scaffold: \`${version}\``);
    if (overlay)
      lines.push(`- Overlay: [\`${overlay}\`](../../${overlay}) — exposes/replaces \`pkgs.${name}\``);

    emit(`packages/${name}.md`, {
      type: "Nix Package",
      title: titleFromSlug(name),
      description: firstSentence(desc),
      resource: srcRel,
      tags: ["package"],
      timestamp: gitISO(srcRel),
    }, lines.join("\n"));
  }

  // --- Overlay-only entries (no pkgs/ counterpart) ------------------------------
  for (const entry of repo.nixFiles("overlays").filter((f) => f.endsWith(".nix"))) {
    const name = entry.replace(/\.nix$/, "");
    if (pkgNames.has(name)) continue;
    const srcRel = `overlays/${entry}`;
    const src = repo.read(srcRel);
    const desc = leadingComment(src) ?? `Nixpkgs overlay '${name}'`;
    emit(`packages/${name}.md`, {
      type: "Overlay",
      title: titleFromSlug(name),
      description: firstSentence(desc),
      resource: srcRel,
      tags: ["overlay"],
      timestamp: gitISO(srcRel),
    }, [
      mdSafe(sentence(desc)),
      "",
      "## Source",
      "",
      `- Overlay: [\`${srcRel}\`](../../${srcRel})`,
    ].join("\n"));
  }

  // --- Sub-flakes -> knowledge/packages/<name>.md -------------------------------
  console.log("sub-flakes:");
  for (const entry of repo.nixFiles("flakes")) {
    const flakeRel = `flakes/${entry}/flake.nix`;
    if (!repo.exists(flakeRel)) continue;
    const src = repo.read(flakeRel);
    const desc = firstMatch(src, /description\s*=\s*"([^"]+)"/) ?? `Sub-flake '${entry}'`;
    const readme = repo.exists(`flakes/${entry}/README.md`)
      ? `flakes/${entry}/README.md`
      : null;
    const lines = [
      mdSafe(sentence(desc)),
      "",
      "Consumed by the root flake as a relative-path input — see the",
      "[sub-flake extraction pattern](../patterns/subflake-extraction.md).",
      "",
      "## Source",
      "",
      `- Flake: [\`flakes/${entry}/\`](../../flakes/${entry}/)`,
    ];
    if (readme) lines.push(`- README: [\`${readme}\`](../../${readme})`);
    emit(`packages/${entry}.md`, {
      type: "Sub-flake",
      title: entry,
      description: firstSentence(desc),
      resource: `flakes/${entry}/`,
      tags: ["sub-flake", "package"],
      timestamp: gitISO(`flakes/${entry}`),
    }, lines.join("\n"));
  }
}
