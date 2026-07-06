// Scaffold pass: hosts and host-specific files. modules/hosts/ holds one
// folder per host (exact hostname), each with a default.nix declaring
// configurations.(darwin|nixos).<hostname> plus any files specific to that
// host (e.g. SOC-Kris-Williams/alias-en0.nix). A flat <host>.nix is also
// recognized for compatibility (nebula-snowglobe's layout). Emits
// knowledge/hosts/<name>.md per host and knowledge/modules/<slug>.md per
// host-specific file; `moduleNames` comes from the modules pass (enable-flag
// filter + doc-slug collision check).

import type { ScaffoldContext } from "./scaffold-api";
import { classTag, docType, type ClassName, type Repo } from "./lib";

export function scaffoldHosts(
  ctx: ScaffoldContext,
  repo: Repo,
  moduleNames: ReadonlySet<string>,
): void {
  const { emit, titleFromSlug, sentence, firstSentence, mdSafe } = ctx;
  const gitISO = ctx.timestamp;

  /** Leading `# …` comment block at the top of a .nix file, joined. */
  const leadingComment = (src: string) => ctx.leadingComment(src, "#");

  const hosts: Array<{ name: string; srcRel: string; src: string }> = [];
  const hostFiles: Array<{ name: string; host: string; srcRel: string; src: string }> = [];
  for (const entry of repo.nixFiles("modules/hosts")) {
    if (entry.endsWith(".nix")) {
      const name = entry.replace(/\.nix$/, "");
      hosts.push({ name, srcRel: `modules/hosts/${entry}`, src: repo.read(`modules/hosts/${entry}`) });
    } else if (repo.stat(`modules/hosts/${entry}`)?.isDirectory()) {
      // Recursive: import-tree discovers .nix files at any depth (e.g.
      // nebula/users/k/helium.nix), so nested files are host files too, named
      // by their path (users/k/helium.nix -> users-k-helium).
      const walk = (relDir: string, prefix: string) => {
        for (const sub of repo.nixFiles(relDir)) {
          // stat follows symlinks — a dangling one must be skipped, not
          // crash the scaffolder.
          const st = repo.stat(`${relDir}/${sub}`);
          if (!st) {
            console.log(`  ! ${relDir}/${sub}: unstat-able (dangling symlink?) — skipped`);
          } else if (st.isDirectory()) {
            walk(`${relDir}/${sub}`, `${prefix}${sub}-`);
          } else if (sub === "default.nix") {
            const srcRel = `${relDir}/default.nix`;
            if (prefix === "") hosts.push({ name: entry, srcRel, src: repo.read(srcRel) });
            else hostFiles.push({ name: prefix.slice(0, -1), host: entry, srcRel, src: repo.read(srcRel) });
          } else if (sub.endsWith(".nix")) {
            const srcRel = `${relDir}/${sub}`;
            hostFiles.push({ name: prefix + sub.replace(/\.nix$/, ""), host: entry, srcRel, src: repo.read(srcRel) });
          }
        }
      };
      walk(`modules/hosts/${entry}`, "");
    }
  }
  // A host's class decides the wording and typing of its docs and its
  // host-specific files' docs. Detected from the actual registration in
  // comment-stripped source — comments here routinely name the other class
  // (nebula.nix's own header mentions its registry), so a raw substring match
  // would misclassify.
  const stripNixComments = (src: string) =>
    src.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|\s)#.*$/gm, "$1");
  const hostClass = new Map<string, ClassName>();
  for (const h of hosts) {
    const code = stripNixComments(h.src);
    const cls: ClassName | null = /configurations\.nixos\./.test(code)
      ? "nixos"
      : /configurations\.darwin\./.test(code)
        ? "darwin"
        : null;
    if (!cls)
      console.log(`  ! ${h.srcRel}: no configurations.<class> registration found — assuming darwin`);
    hostClass.set(h.name, cls ?? "darwin");
  }
  // Host-file docs inherit their directory's class; a dir without a same-named
  // registration is flagged loudly instead of silently defaulting to darwin.
  const dirClass = new Map<string, ClassName>();
  for (const hf of hostFiles) {
    if (dirClass.has(hf.host)) continue;
    const cls = hostClass.get(hf.host);
    if (!cls)
      console.log(
        `  ! modules/hosts/${hf.host}: no same-named host registration — class unknown, assuming darwin`,
      );
    dirClass.set(hf.host, cls ?? "darwin");
  }

  console.log("host-specific files:");
  // Host-qualify a doc name when its basename collides with a module doc or
  // another host's same-named file — emit() skips existing files, which would
  // otherwise silently drop the second source's doc.
  const hostFileSlug = new Map<string, string>();
  {
    const taken = new Set(moduleNames);
    for (const hf of hostFiles) {
      const slug = taken.has(hf.name) ? `${hf.host}-${hf.name}` : hf.name;
      if (slug !== hf.name) console.log(`  ! ${hf.srcRel}: basename taken, doc is modules/${slug}.md`);
      taken.add(slug);
      taken.add(hf.name);
      hostFileSlug.set(hf.srcRel, slug);
    }
  }
  for (const { name, host, srcRel, src } of hostFiles) {
    const slug = hostFileSlug.get(srcRel)!;
    const cls = dirClass.get(host)!;
    const desc = leadingComment(src) ?? `Host-specific config '${name}' for ${host}`;
    emit(`modules/${slug}.md`, {
      type: docType(cls),
      title: titleFromSlug(name),
      description: firstSentence(desc),
      resource: srcRel,
      tags: [classTag(cls), "host-specific"],
      timestamp: gitISO(srcRel),
    }, [
      mdSafe(sentence(desc)),
      "",
      `Host-specific file for [${host}](../hosts/${host}.md) — merged straight into`,
      "that host's configuration per the",
      "[host-mounted modules pattern](../patterns/host-mounted-modules.md).",
      "",
      "## Source",
      "",
      `- Module: [\`${srcRel}\`](../../${srcRel})`,
    ].join("\n"));
  }

  console.log("hosts:");
  for (const { name, srcRel, src } of hosts) {
    const desc = leadingComment(src) ?? `Host configuration '${name}'`;
    // Features this host opts into (enable flags flipped in the host module),
    // plus its host-specific sibling files. Two enable spellings: the dotted
    // one-liner `programs.<name>.enable = true;` and the attrset form
    // `programs.<name> = { enable = true; ... };` (bounded window so a nested
    // sub-attrset's enable isn't credited to the outer name).
    const enabled = [
      ...new Set(
        [
          ...[...src.matchAll(/([A-Za-z0-9_-]+)\.enable\s*=\s*true/g)].map((m) => m[1]),
          ...[...src.matchAll(/([A-Za-z0-9_-]+)\s*=\s*\{[^{}]{0,200}?\benable\s*=\s*true/g)].map(
            (m) => m[1],
          ),
        ].filter((f) => moduleNames.has(f)),
      ),
    ].sort();
    const extras = hostFiles
      .filter((m) => m.host === name)
      .map((m) => ({ text: m.name, slug: hostFileSlug.get(m.srcRel)! }))
      .sort((a, b) => a.text.localeCompare(b.text));
    const featureLines = [
      ...enabled.map((f) => `- [${f}](../modules/${f}.md)`),
      ...extras.map((f) => `- [${f.text}](../modules/${f.slug}.md) (host-specific file)`),
    ];

    emit(`hosts/${name}.md`, {
      type: "Host",
      title: name,
      description: firstSentence(desc),
      resource: srcRel,
      tags: ["host"],
      timestamp: gitISO(srcRel),
    }, [
      mdSafe(sentence(desc)),
      "",
      // The nixos class is all-universal — its hosts have host-specific files,
      // not opt-in feature flags, and the doc must not claim otherwise.
      ...(hostClass.get(name) === "nixos"
        ? [
            "Imports every [NixOS module](../modules/index.md) — the nixos class is",
            "all-universal (no enable gates); the entries below are host-specific",
            "files merged straight into this host's configuration (see the",
            "[host-mounted modules pattern](../patterns/host-mounted-modules.md)).",
            "",
            "## Host-specific files",
          ]
        : [
            "Imports every [darwin module](../modules/index.md); host-selective features",
            "are opted into below per the",
            "[host-mounted modules pattern](../patterns/host-mounted-modules.md).",
            "",
            "## Host-selective features",
          ]),
      "",
      ...(featureLines.length ? featureLines : ["- (universal modules only)"]),
      "",
      "## Source",
      "",
      `- Host module: [\`${srcRel}\`](../../${srcRel})`,
    ].join("\n"));
  }
}
