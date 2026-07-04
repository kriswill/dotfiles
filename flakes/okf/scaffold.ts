// Scaffold catalog concept stubs from the repo itself — the Nix analog of the
// OKF reference agent's metadata pass. Walks modules/, pkgs/, overlays/,
// flakes/, modules/hosts/ and the Neovim plugin specs, and writes one stub per
// component into knowledge/{modules,packages,hosts,nvim/plugins}/. Idempotent:
// existing docs are never overwritten (enrichment happens by hand or by
// agents), use --force to redo.

import { readdirSync, readFileSync, writeFileSync, mkdirSync, existsSync, statSync } from "node:fs";
import { join } from "node:path";
import { bundleRoot, fmToYaml, gitISO, repoRoot, titleFromSlug, type FM } from "./lib";

const FORCE = process.argv.includes("--force");
const repo = repoRoot();
const bundle = bundleRoot();
let written = 0, skipped = 0;

function emit(rel: string, fm: FM, body: string) {
  const abs = join(bundle, rel);
  if (existsSync(abs) && !FORCE) { skipped++; return; }
  mkdirSync(join(abs, ".."), { recursive: true });
  writeFileSync(abs, fmToYaml(fm) + "\n" + body.trim() + "\n");
  written++;
  console.log(`  + ${rel}`);
}

function read(rel: string): string {
  return readFileSync(join(repo, rel), "utf8");
}

/** Leading comment block at the top of a file, joined. */
function leadingCommentWith(src: string, marker: RegExp): string | null {
  const lines: string[] = [];
  for (const line of src.split("\n")) {
    const m = line.match(marker);
    if (m) lines.push(m[1]);
    else if (line.trim() === "") continue;
    else break;
  }
  const text = lines.join(" ").trim();
  return text || null;
}

/** Leading `# …` comment block at the top of a .nix file, joined. */
const leadingComment = (src: string) => leadingCommentWith(src, /^#\s?(.*)$/);

/** Leading `-- …` comment block at the top of a .lua file, joined. */
const leadingLuaComment = (src: string) => leadingCommentWith(src, /^--\s?(.*)$/);

function firstMatch(src: string, re: RegExp): string | null {
  const m = src.match(re);
  return m ? m[1] : null;
}

const clean = (s: string) => s.replace(/\s+/g, " ").trim();

/** Wrap bare URLs in angle brackets (MD034) for use in markdown bodies. */
const mdSafe = (s: string) => s.replace(/(^|[\s(])(https?:\/\/[^\s)>]+)/g, "$1<$2>");

function sentence(s: string): string {
  const t = clean(s);
  return /[.!?]$/.test(t) ? t : t + ".";
}

/** First sentence, for frontmatter descriptions (full text stays in the body). */
function firstSentence(s: string): string {
  const t = clean(s);
  const m = t.match(/^.*?[.!?](?=\s|$)/);
  return m ? m[0] : sentence(t);
}

const nixFiles = (dir: string) =>
  readdirSync(join(repo, dir))
    .filter((f) => !f.startsWith("_") && !f.startsWith("."))
    .sort();

// --- Feature modules (darwin + nixos classes) -> knowledge/modules/<name>.md
// A feature present in both class dirs is a cross-OS twin (AGENTS.md): one doc
// covers both implementations.
const CLASSES = ["darwin", "nixos"] as const;
type ClassName = (typeof CLASSES)[number];
const CLASS_LABEL: Record<ClassName, string> = { darwin: "darwin", nixos: "NixOS" };
const docType = (cls: ClassName) => (cls === "darwin" ? "Darwin Module" : "NixOS Module");
const classTag = (cls: ClassName) => `${cls}-module`;
const featureSrcs = new Map<string, Partial<Record<ClassName, string>>>();
for (const cls of CLASSES) {
  for (const entry of nixFiles(`modules/${cls}`)) {
    let name: string, srcRel: string;
    if (entry.endsWith(".nix")) {
      name = entry.replace(/\.nix$/, "");
      srcRel = `modules/${cls}/${entry}`;
    } else if (existsSync(join(repo, `modules/${cls}`, entry, "default.nix"))) {
      name = entry;
      srcRel = `modules/${cls}/${entry}/default.nix`;
    } else continue;
    featureSrcs.set(name, { ...featureSrcs.get(name), [cls]: srcRel });
  }
}
// Feature names, for the host enable-flag filter and host-file slug collision
// check below (plumbing modules add theirs as they're scanned).
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
    const src = read(srcs[cls]!);
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
    classes.map((c) => `modules/${c}/${name}/README.md`).find((r) => existsSync(join(repo, r))) ??
    null;
  const stow = existsSync(join(repo, "home", name)) ? `home/${name}/` : null;

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
for (const entry of nixFiles("modules").filter((f) => f.endsWith(".nix"))) {
  const name = entry.replace(/\.nix$/, "");
  const srcRel = `modules/${entry}`;
  const src = read(srcRel);
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

// --- Hosts + host-specific files ----------------------------------------------
// modules/hosts/ holds one folder per host (exact hostname), each with a
// default.nix declaring configurations.(darwin|nixos).<hostname> plus any
// files specific to that host (e.g. SOC-Kris-Williams/alias-en0.nix). A flat
// <host>.nix is also recognized for compatibility (nebula-snowglobe's layout).
const hosts: Array<{ name: string; srcRel: string; src: string }> = [];
const hostFiles: Array<{ name: string; host: string; srcRel: string; src: string }> = [];
for (const entry of nixFiles("modules/hosts")) {
  if (entry.endsWith(".nix")) {
    const name = entry.replace(/\.nix$/, "");
    hosts.push({ name, srcRel: `modules/hosts/${entry}`, src: read(`modules/hosts/${entry}`) });
  } else if (statSync(join(repo, "modules/hosts", entry), { throwIfNoEntry: false })?.isDirectory()) {
    // Recursive: import-tree discovers .nix files at any depth (e.g.
    // nebula/users/k/helium.nix), so nested files are host files too, named
    // by their path (users/k/helium.nix -> users-k-helium).
    const walk = (relDir: string, prefix: string) => {
      for (const sub of nixFiles(relDir)) {
        // statSync follows symlinks — a dangling one must be skipped, not
        // crash the scaffolder.
        const st = statSync(join(repo, relDir, sub), { throwIfNoEntry: false });
        if (!st) {
          console.log(`  ! ${relDir}/${sub}: unstat-able (dangling symlink?) — skipped`);
        } else if (st.isDirectory()) {
          walk(`${relDir}/${sub}`, `${prefix}${sub}-`);
        } else if (sub === "default.nix") {
          const srcRel = `${relDir}/default.nix`;
          if (prefix === "") hosts.push({ name: entry, srcRel, src: read(srcRel) });
          else hostFiles.push({ name: prefix.slice(0, -1), host: entry, srcRel, src: read(srcRel) });
        } else if (sub.endsWith(".nix")) {
          const srcRel = `${relDir}/${sub}`;
          hostFiles.push({ name: prefix + sub.replace(/\.nix$/, ""), host: entry, srcRel, src: read(srcRel) });
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

// --- Custom packages -> knowledge/packages/<name>.md -------------------------
console.log("packages:");
const pkgNames = new Set<string>();
for (const entry of nixFiles("pkgs").filter((f) => f.endsWith(".nix"))) {
  const name = entry.replace(/\.nix$/, "");
  pkgNames.add(name);
  const srcRel = `pkgs/${entry}`;
  const src = read(srcRel);
  const desc =
    firstMatch(src, /description\s*=\s*"([^"]+)"/) ??
    leadingComment(src) ??
    `Custom Nix package '${name}'`;
  const version = firstMatch(src, /version\s*=\s*"([^"]+)"/);
  const overlay = existsSync(join(repo, `overlays/${name}.nix`)) ? `overlays/${name}.nix` : null;

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
for (const entry of nixFiles("overlays").filter((f) => f.endsWith(".nix"))) {
  const name = entry.replace(/\.nix$/, "");
  if (pkgNames.has(name)) continue;
  const srcRel = `overlays/${entry}`;
  const src = read(srcRel);
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
for (const entry of nixFiles("flakes")) {
  const flakeRel = `flakes/${entry}/flake.nix`;
  if (!existsSync(join(repo, flakeRel))) continue;
  const src = read(flakeRel);
  const desc = firstMatch(src, /description\s*=\s*"([^"]+)"/) ?? `Sub-flake '${entry}'`;
  const readme = existsSync(join(repo, `flakes/${entry}/README.md`))
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

// --- Neovim plugins -> knowledge/nvim/plugins/<name>.md ----------------------
// Each spec file under lua/plugins/ (or dir with init.lua) is one plugin,
// dispatched by lua/config/pack.lua — see knowledge/nvim/architecture.md.
console.log("neovim plugins:");
const NVIM_PLUGINS = "home/nvim/.config/nvim/lua/plugins";
for (const entry of nixFiles(NVIM_PLUGINS)) {
  let name: string, srcRel: string, resource: string;
  if (entry.endsWith(".lua")) {
    name = entry.replace(/\.lua$/, "");
    srcRel = `${NVIM_PLUGINS}/${entry}`;
    resource = srcRel;
  } else if (existsSync(join(repo, NVIM_PLUGINS, entry, "init.lua"))) {
    name = entry;
    srcRel = `${NVIM_PLUGINS}/${entry}/init.lua`;
    resource = `${NVIM_PLUGINS}/${entry}/`;
  } else continue;

  const src = read(srcRel);
  const desc = leadingLuaComment(src) ?? `Neovim plugin '${name}'`;
  const trigger =
    firstMatch(src, /trigger\s*=\s*"(\w+)"/) ??
    firstMatch(src, /trigger\s*=\s*\{\s*(ft|cmd|keys)/) ??
    "now";
  const version =
    firstMatch(src, /version\s*=\s*"([^"]+)"/) ??
    firstMatch(src, /version\s*=\s*(vim\.version\.range\([^)]*\))/);
  const urls = [...new Set([...src.matchAll(/src\s*=\s*"([^"]+)"/g)].map((m) => m[1]))];

  const lines = [
    mdSafe(sentence(desc)),
    "",
    "Declared as a pack spec under `lua/plugins/` and dispatched by the",
    "[plugin architecture](../architecture.md) (trigger: `" + trigger + "`).",
    "",
    "## Source",
    "",
    `- Spec: [\`${resource}\`](../../../${resource})`,
  ];
  if (urls.length) lines.push(`- Upstream: <${urls[0]}>`);
  for (const dep of urls.slice(1)) lines.push(`- Bundled dep: <${dep}>`);
  if (version) lines.push(`- Version pin: \`${version}\``);

  emit(`nvim/plugins/${name}.md`, {
    type: "Neovim Plugin",
    title: titleFromSlug(name),
    description: firstSentence(desc),
    resource,
    tags: ["nvim-plugin"],
    timestamp: gitISO(srcRel),
  }, lines.join("\n"));
}

console.log(`\nscaffold: ${written} written, ${skipped} skipped (existing)${FORCE ? " [--force]" : ""}`);
