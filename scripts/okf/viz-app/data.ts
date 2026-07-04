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
}

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
  typeCounts: Record<string, number>;
  allTypes: string[];
  /** Legend cluster per type, derived from each type's concepts' top-level bundle directory. */
  typeGroup: Record<string, string>;
  /** Types per legend cluster, in allTypes order. */
  groupTypes: Record<string, string[]>;
  /** GROUP_ORDER filtered to present clusters, "Other" appended only if non-empty. */
  groupOrder: string[];
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
  for (const e of edges) {
    deg[e.s] = (deg[e.s] || 0) + 1;
    deg[e.t] = (deg[e.t] || 0) + 1;
    (inLinks[e.t] = inLinks[e.t] || []).push(e.s);
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
    typeCounts,
    allTypes,
    typeGroup,
    groupTypes,
    groupOrder,
    radii,
  };
}

export function loadFromDom(): VizModel {
  return buildModel(JSON.parse(document.getElementById("data")!.textContent!));
}
