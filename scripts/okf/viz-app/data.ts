// Immutable data model built once from the #data JSON blob baked in by
// scripts/okf/viz.ts. Everything here is pure and framework-free.

export interface ConceptNode {
  id: string;
  type: string;
  title: string;
  desc: string;
  fm: Record<string, unknown>;
  body: string;
  x: number;
  y: number;
  z: number;
}

export interface EmbeddedFile {
  html: string;
  lines: number;
  size: number;
  date: string;
  lang: string;
  refs: string[];
  /** Raw source, present for markdown files — rendered instead of `html`. */
  md?: string;
}

export interface EmbeddedDir {
  /** Immediate child files (repo-relative; a child may be unembedded if too big/binary). */
  files: string[];
  /** Immediate child directories (repo-relative, each with its own entry). */
  dirs: string[];
  date: string;
  refs: string[];
}

export interface RawData {
  nodes: ConceptNode[];
  edges: { s: string; t: string }[];
  files?: Record<string, EmbeddedFile>;
  dirs?: Record<string, EmbeddedDir>;
  /** https://github.com/owner/repo, for outbound commit links (null: no GitHub origin). */
  repoUrl?: string | null;
  /** Verified commit-hash citations: literal as written -> full oid. */
  commits?: Record<string, string>;
  /** Package name -> platform for OS-guarded packages (parsed from modules/packages.nix). */
  pkgPlatforms?: Record<string, "darwin" | "nixos">;
}

export type Platform = "darwin" | "nixos" | "both" | "neutral";

export interface VizModel {
  nodes: ConceptNode[];
  files: Record<string, EmbeddedFile>;
  dirs: Record<string, EmbeddedDir>;
  repoUrl: string | null;
  commits: Record<string, string>;
  byId: Record<string, ConceptNode>;
  indexOf: Map<string, number>;
  edges: { s: string; t: string }[];
  edgeIdx: [number, number][];
  deg: Record<string, number>;
  inLinks: Record<string, string[]>;
  /** Undirected adjacency by id, for neighborhood isolation. */
  adjById: Record<string, Set<string>>;
  typeCounts: Record<string, number>;
  allTypes: string[];
  /** Legend cluster per type, derived from each type's concepts' top-level bundle directory. */
  typeGroup: Record<string, string>;
  /** Types per legend cluster, in allTypes order. */
  groupTypes: Record<string, string[]>;
  /** GROUP_ORDER filtered to present clusters, "Other" appended only if non-empty. */
  groupOrder: string[];
  /** OS a concept applies to, per node id (derived from type/host/package guards). */
  platformById: Record<string, Platform>;
  /** Scene sphere radius per node (same order as nodes). */
  radii: number[];
}

// Fixed palette slot order (never cycled): slot N = CSS var --sN in every
// theme (viz-app/themes.ts). Append-only — existing types keep their colors.
// Types not listed here get a stable generated color (viz-app/color.ts).
export const TYPE_ORDER = [
  "Darwin Module",
  "Nix Package",
  "Playbook",
  "Pattern",
  "Decision",
  "Host",
  "Sub-flake",
  "Flake-parts Module",
  "Neovim Config",
  "Neovim Plugin",
  "Overlay",
  "Reference",
];

// A concept's id is its bundle-relative path minus ".md" (viz.ts) — the
// top-level path segment is already a stable, zero-maintenance topology
// signal. Root docs (no '/') group as ".".
export function dirOf(id: string): string {
  return id.includes("/") ? id.split("/")[0]! : ".";
}

// Static, append-only map from a top-level bundle directory to its legend
// cluster. A directory not listed here buckets into "Other" (buildModel)
// instead of crashing — a safety net for a future top-level directory.
export const GROUP_OF_DIR: Record<string, string> = {
  decisions: "Knowledge",
  patterns: "Knowledge",
  playbooks: "Knowledge",
  ".": "Knowledge",
  modules: "System",
  hosts: "System",
  packages: "Packages",
  nvim: "Neovim",
};

export const GROUP_ORDER = ["Knowledge", "System", "Packages", "Neovim"];

// The repo's only nixos host; every other host is darwin. Extend if a second
// nixos host appears (same maintenance model as GROUP_OF_DIR).
const NIXOS_HOSTS = new Set(["nebula"]);

const basename = (id: string) => id.split("/").pop() ?? id;

/**
 * Package-name -> OS for the OS-guarded packages in modules/packages.nix.
 * The file has two `lib.optionalAttrs (<pred>) { <attrs> }` blocks — one
 * darwin-guarded, one linux-guarded; everything outside them is universal
 * (absent from the map -> "both"). Brace-depth scan, not a lazy regex: an
 * attr RHS like `inputs.x.packages.${system}.x` contains a `}` that would
 * truncate a non-greedy capture and silently drop later attrs. Any structural
 * change to the file degrades the affected packages to "both" — never throws.
 */
export function parsePackagePlatforms(nixSource: string): Record<string, "darwin" | "nixos"> {
  const out: Record<string, "darwin" | "nixos"> = {};
  const re = /optionalAttrs\s*\(([^{]*)\{/g; // predicate text up to the block-opening brace
  for (let m = re.exec(nixSource); m; m = re.exec(nixSource)) {
    const pred = m[1]!;
    const os: "darwin" | "nixos" | null = pred.includes("darwin")
      ? "darwin"
      : pred.includes("linux")
        ? "nixos"
        : null;
    if (!os) continue;
    // Scan from just after the '{' to its matching close (depth 0).
    let depth = 1;
    let i = m.index + m[0].length;
    for (; i < nixSource.length && depth > 0; i++) {
      const c = nixSource[i];
      if (c === "{") depth++;
      else if (c === "}") depth--;
    }
    if (depth !== 0) continue; // unbalanced (EOF) — bail, don't misclassify
    // Keep only the block's depth-0 text: dropping every nested `{...}` (callPackage
    // args, `${system}` interps) means a nested `arg =` on its own line can never be
    // mistaken for a top-level package attr.
    let d = 0;
    let top = "";
    for (const c of nixSource.slice(m.index + m[0].length, i - 1)) {
      if (c === "{") d++;
      else if (c === "}") d--;
      else if (d === 0) top += c;
    }
    for (const a of top.matchAll(/(?:^|\n)[ \t]*([A-Za-z][\w-]*)[ \t]*=/g)) out[a[1]!] = os;
    re.lastIndex = i; // resume after this block
  }
  return out;
}

/** OS a concept applies to, derived from its type, id, and the package guards. */
export function platformOf(type: string, id: string, pkgPlatforms: Record<string, "darwin" | "nixos">): Platform {
  switch (type) {
    case "Darwin Module":
      return "darwin";
    case "NixOS Module":
      return "nixos";
    case "Dual Module":
    case "Flake-parts Module":
    case "Neovim Plugin":
    case "Neovim Config":
      return "both";
    case "Host":
      return NIXOS_HOSTS.has(basename(id)) ? "nixos" : "darwin";
    case "Nix Package":
    case "Sub-flake":
    case "Overlay":
      return pkgPlatforms[basename(id)] ?? "both";
    default:
      // Decision/Pattern/Playbook/Reference and any unknown type: cross-cutting,
      // never hidden by an OS filter.
      return "neutral";
  }
}

export function buildModel(raw: RawData): VizModel {
  const nodes = raw.nodes;
  const files = raw.files || {};
  const dirs = raw.dirs || {};
  const repoUrl = raw.repoUrl || null;
  const commits = raw.commits || {};
  const byId: Record<string, ConceptNode> = Object.fromEntries(nodes.map((n) => [n.id, n]));
  const indexOf = new Map(nodes.map((n, i) => [n.id, i]));
  const edges = raw.edges.filter((e) => byId[e.s] && byId[e.t]);
  const edgeIdx: [number, number][] = edges.map((e) => [indexOf.get(e.s)!, indexOf.get(e.t)!]);

  const deg: Record<string, number> = {};
  const inLinks: Record<string, string[]> = {};
  const adjById: Record<string, Set<string>> = {};
  for (const n of nodes) adjById[n.id] = new Set();
  for (const e of edges) {
    deg[e.s] = (deg[e.s] || 0) + 1;
    deg[e.t] = (deg[e.t] || 0) + 1;
    (inLinks[e.t] = inLinks[e.t] || []).push(e.s);
    adjById[e.s]!.add(e.t);
    adjById[e.t]!.add(e.s);
  }

  const typeCounts: Record<string, number> = {};
  for (const n of nodes) typeCounts[n.type] = (typeCounts[n.type] || 0) + 1;
  const allTypes = [
    ...TYPE_ORDER.filter((t) => typeCounts[t]),
    ...Object.keys(typeCounts)
      .filter((t) => !TYPE_ORDER.includes(t))
      .sort(),
  ];

  // The profile keeps every type inside one top-level directory, so this is
  // normally unambiguous; if that's ever violated, the first concept of a
  // type fixes its group (deterministic, not "last write wins").
  const typeGroup: Record<string, string> = {};
  for (const n of nodes) typeGroup[n.type] ??= GROUP_OF_DIR[dirOf(n.id)] ?? "Other";
  const groupTypes: Record<string, string[]> = {};
  for (const t of allTypes) (groupTypes[typeGroup[t]!] ??= []).push(t);
  const groupOrder = [...GROUP_ORDER.filter((g) => groupTypes[g]), ...(groupTypes["Other"] ? ["Other"] : [])];

  const pkgPlatforms = raw.pkgPlatforms ?? {};
  const platformById: Record<string, Platform> = {};
  for (const n of nodes) platformById[n.id] = platformOf(n.type, n.id, pkgPlatforms);

  const radii = nodes.map((n) => (3.5 + Math.min(6.5, (deg[n.id] || 0) * 0.8)) * 0.42);

  return {
    nodes,
    files,
    dirs,
    repoUrl,
    commits,
    byId,
    indexOf,
    edges,
    edgeIdx,
    deg,
    inLinks,
    adjById,
    typeCounts,
    allTypes,
    typeGroup,
    groupTypes,
    groupOrder,
    platformById,
    radii,
  };
}

/** BFS neighbor set within `depth` hops of `id`, including `id` itself so the
 *  origin never vanishes from its own filtered view. An id absent from the
 *  model returns an empty set; a real but edge-less node returns itself. */
export function neighborsWithin(model: VizModel, id: string, depth: 1 | 2): Set<string> {
  const seen = new Set<string>();
  if (!model.adjById[id]) return seen;
  seen.add(id);
  let frontier = [id];
  for (let d = 0; d < depth; d++) {
    const next: string[] = [];
    for (const cur of frontier) {
      for (const nb of model.adjById[cur] ?? []) {
        if (!seen.has(nb)) {
          seen.add(nb);
          next.push(nb);
        }
      }
    }
    frontier = next;
  }
  return seen;
}

export function loadFromDom(): VizModel {
  return buildModel(JSON.parse(document.getElementById("data")!.textContent!));
}
