// Scaffold pass: feature modules (darwin + nixos classes) and flake-parts
// plumbing modules -> knowledge/modules/<name>.md. A feature present in both
// class dirs is a cross-OS twin (AGENTS.md): one doc covers both
// implementations. Returns the full module-name set — the hosts pass filters
// enable flags against it and host-qualifies doc slugs that would collide.

import type { ScaffoldContext } from "./scaffold-api";
import {
  CLASS_LABEL,
  CLASSES,
  classTag,
  docType,
  type ClassName,
  type Repo,
} from "./lib";

export function scaffoldModules(ctx: ScaffoldContext, repo: Repo): Set<string> {
  const { emit, titleFromSlug, sentence, firstSentence, mdSafe, firstMatch } = ctx;
  const gitISO = ctx.timestamp;

  /** Leading `# …` comment block at the top of a .nix file, joined. */
  const leadingComment = (src: string) => ctx.leadingComment(src, "#");

  const featureSrcs = new Map<string, Partial<Record<ClassName, string>>>();
  for (const cls of CLASSES) {
    for (const entry of repo.nixFiles(`modules/${cls}`)) {
      let name: string, srcRel: string;
      if (entry.endsWith(".nix")) {
        name = entry.replace(/\.nix$/, "");
        srcRel = `modules/${cls}/${entry}`;
      } else if (repo.exists(`modules/${cls}/${entry}/default.nix`)) {
        name = entry;
        srcRel = `modules/${cls}/${entry}/default.nix`;
      } else continue;
      featureSrcs.set(name, { ...featureSrcs.get(name), [cls]: srcRel });
    }
  }
  // Feature names, returned for the hosts pass's enable-flag filter and
  // host-file slug collision check (plumbing modules add theirs as they're
  // scanned).
  const moduleNames = new Set(featureSrcs.keys());

  // Per-class gating info — computed per source and NEVER flattened across
  // classes: a twin may be gated on darwin while its nixos twin is universal
  // (the nixos class is all-universal today). Gating detection: an enable
  // option declared in the file itself, or — for sub-flake re-exports whose
  // options live in the re-exported module — a backticked `<ns>.enable = true;`
  // hint anywhere in the file's comments.
  const optionOf = (src: string) =>
    firstMatch(src, /options\.([A-Za-z0-9_.-]+?)\.enable\s*=/) ??
    firstMatch(src, /options\.([A-Za-z0-9_.-]+?)\s*=\s*\{\s*\n\s*enable\s*=/) ??
    firstMatch(src, /`([A-Za-z0-9_.-]+)\.enable = true;?`/);
  const reExportOf = (src: string) => /inputs\.[A-Za-z0-9_-]+\.(darwin|nixos)Modules\./.test(src);
  /** How one class's implementation mounts, as a mid-sentence clause. */
  function mountClause(s: { cls: ClassName; option: string | null; reExport: boolean }): string {
    if (s.option)
      return `imported on every ${CLASS_LABEL[s.cls]} host but disabled by default — hosts opt in with \`${s.option}.enable = true;\``;
    if (s.reExport)
      return `re-exports a module whose options ship with the re-exported flake, so ${CLASS_LABEL[s.cls]} hosts opt in via its enable option`;
    return `mounted ungated on every ${CLASS_LABEL[s.cls]} host`;
  }

  console.log("feature modules:");
  for (const [name, srcs] of [...featureSrcs].sort(([a], [b]) => a.localeCompare(b))) {
    const classes = CLASSES.filter((c) => srcs[c]);
    const twin = classes.length === 2;
    const sources = classes.map((cls) => {
      const src = repo.read(srcs[cls]!);
      return { cls, rel: srcs[cls]!, src, option: optionOf(src) ?? null, reExport: reExportOf(src) };
    });
    const primaryRel = sources[0].rel;
    // Leading comment first — `description = "..."` regexes match arbitrary
    // option descriptions (e.g. a settings option's), not the module's purpose.
    const desc =
      sources.map(({ src }) => leadingComment(src)).find(Boolean) ??
      sources.map(({ src }) => firstMatch(src, /mkEnableOption\s+"([^"]+)"/)).find(Boolean) ??
      sources.map(({ src }) => firstMatch(src, /description\s*=\s*"([^"]+)"/)).find(Boolean) ??
      `Feature module '${name}' (${classes.join(" + ")})`;
    const readme =
      classes.map((c) => `modules/${c}/${name}/README.md`).find((r) => repo.exists(r)) ?? null;
    const stow = repo.exists(`home/${name}`) ? `home/${name}/` : null;

    // Twins whose halves gate identically share one sentence; differing halves
    // are described per class, so a gated darwin module never claims its
    // universal nixos twin is opt-in (or vice versa).
    const sameShape =
      !twin ||
      (sources[0].option === sources[1].option && sources[0].reExport === sources[1].reExport);
    const patternSuffix = [
      "(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));",
      "auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).",
    ];
    let mountLines: string[];
    if (sameShape) {
      const s0 = sources[0];
      const hostsPhrase = twin ? "every host of both classes" : `every ${CLASS_LABEL[s0.cls]} host`;
      mountLines = s0.option
        ? [
            `Imported on ${hostsPhrase} but disabled by default — hosts opt in with`,
            `\`${s0.option}.enable = true;\``,
            ...patternSuffix,
          ]
        : s0.reExport
          ? [
              "Re-exports a module whose options ship with the re-exported flake —",
              "disabled by default; hosts opt in via its enable option",
              ...patternSuffix,
            ]
          : [`Mounted ungated on ${hostsPhrase}`, ...patternSuffix];
    } else {
      const [a, b] = sources;
      const first = mountClause(a);
      mountLines = [
        `${first.charAt(0).toUpperCase()}${first.slice(1)};`,
        `${mountClause(b)}`,
        ...patternSuffix,
      ];
    }
    if (twin)
      mountLines.push(
        "A cross-OS twin — parallel implementations in each class dir (see the",
        "[cross-OS module twins pattern](../patterns/cross-os-module-twins.md)).",
      );
    const optionLines =
      twin && !sameShape
        ? sources
            .filter((s) => s.option)
            .map((s) => `- Options under: \`${s.option}\` (${CLASS_LABEL[s.cls]})`)
        : sources[0].option
          ? [`- Options under: \`${sources[0].option}\``]
          : [];
    const lines = [
      mdSafe(sentence(desc)),
      "",
      ...mountLines,
      "",
      "## Source",
      "",
      ...sources.map(
        ({ cls, rel }) =>
          `- ${twin ? `${CLASS_LABEL[cls]} module` : "Module"}: [\`${rel}\`](../../${rel})`,
      ),
      ...optionLines,
    ];
    if (stow) lines.push(`- Stow package: [\`${stow}\`](../../${stow}) — see the [stow tree pattern](../patterns/stow-tree.md)`);
    if (readme) lines.push(`- README: [\`${readme}\`](../../${readme})`);

    emit(`modules/${name}.md`, {
      type: twin ? "Dual Module" : docType(classes[0]),
      title: titleFromSlug(name),
      description: firstSentence(desc),
      // Twins: resource points at the darwin implementation; the body's Source
      // section lists both class files (see okf-profile.md).
      resource: primaryRel,
      tags: classes.map(classTag),
      // Newest of the twins' last-commit dates, so a nixos-only change still
      // moves the doc's freshness.
      timestamp: sources
        .map(({ rel }) => gitISO(rel))
        .reduce((a, b) => (Date.parse(b) > Date.parse(a) ? b : a)),
    }, lines.join("\n"));
  }

  // --- Flake plumbing modules -> knowledge/modules/<name>.md ------------------
  console.log("flake-parts plumbing modules:");
  for (const entry of repo.nixFiles("modules").filter((f) => f.endsWith(".nix"))) {
    const name = entry.replace(/\.nix$/, "");
    const srcRel = `modules/${entry}`;
    const src = repo.read(srcRel);
    const desc = leadingComment(src) ?? `Flake-parts plumbing module '${name}'`;
    moduleNames.add(name);
    emit(`modules/${name}.md`, {
      type: "Flake-parts Module",
      title: titleFromSlug(name),
      description: firstSentence(desc),
      resource: srcRel,
      tags: ["flake-parts"],
      timestamp: gitISO(srcRel),
    }, [
      mdSafe(sentence(desc)),
      "",
      "Plumbing layer of the flake — see the [Dendritic module layout](../patterns/dendritic-modules.md).",
      "",
      "## Source",
      "",
      `- Module: [\`${srcRel}\`](../../${srcRel})`,
    ].join("\n"));
  }

  return moduleNames;
}
