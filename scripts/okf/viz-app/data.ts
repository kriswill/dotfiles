// Immutable data model built once from the #data JSON blob baked in by
// scripts/okf/viz.ts. Everything here is pure and framework-free.

import { displayName, normalizeVizConfig, type VizConfig } from "./config";

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
  /** Package name -> platform value for OS-guarded packages (parsed from the
   *  config's platform.packages-nix file). */
  pkgPlatforms?: Record<string, string>;
  /** Normalized VizConfig embedded by the build (absent: generic viewer). */
  cfg?: unknown;
}

/** A config-defined platform value, or the reserved "both" / "neutral". */
export type Platform = string;

export interface VizModel {
  nodes: ConceptNode[];
  files: Record<string, EmbeddedFile>;
  dirs: Record<string, EmbeddedDir>;
  repoUrl: string | null;
  /** "owner/repo" display name from repoUrl (null: no GitHub origin). */
  repoName: string | null;
  /** Normalized viz configuration (generic defaults when unconfigured). */
  cfg: VizConfig;
  /** Header name: cfg.display.name ?? repoName ?? cfg.display.fallbackName. */
  displayName: string;
  /** Platform filter segments after "all" (cfg.platform.values; [] = hidden). */
  platforms: string[];
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
  /** cfg.taxonomy.groupOrder filtered to present clusters, the "other" bucket
   *  appended only if non-empty; [] = flat legend without group headers. */
  groupOrder: string[];
  /** OS a concept applies to, per node id (derived from type/host/package guards). */
  platformById: Record<string, Platform>;
  /** Scene sphere radius per node (same order as nodes). */
  radii: number[];
}

// A concept's id is its bundle-relative path minus ".md" (viz.ts) — the
// top-level path segment is already a stable, zero-maintenance topology
// signal. Root docs (no '/') group as ".".
export function dirOf(id: string): string {
  return id.includes("/") ? id.split("/")[0]! : ".";
}

const basename = (id: string) => id.split("/").pop() ?? id;

/**
 * Package-name -> platform value for the OS-guarded packages in the config's
 * platform.packages-nix file. Each `lib.optionalAttrs (<pred>) { <attrs> }`
 * block is classified by the first `guards` key found in its predicate text
 * (e.g. {darwin: "darwin", linux: "nixos"}); everything outside a matched
 * block is universal (absent from the map -> "both"). Brace-depth scan, not a
 * lazy regex: an attr RHS like `inputs.x.packages.${system}.x` contains a `}`
 * that would truncate a non-greedy capture and silently drop later attrs. Any
 * structural change to the file degrades the affected packages to "both" —
 * never throws.
 */
export function parsePackagePlatforms(nixSource: string, guards: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {};
  const re = /optionalAttrs\s*\(([^{]*)\{/g; // predicate text up to the block-opening brace
  for (let m = re.exec(nixSource); m; m = re.exec(nixSource)) {
    const pred = m[1]!;
    const os = Object.entries(guards).find(([k]) => pred.includes(k))?.[1] ?? null;
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

/** Platform a concept applies to, from the config's platform.types rule table.
 *  "hosts"/"packages" rules indirect through the host list / package guards;
 *  unlisted types are "neutral" (cross-cutting, never hidden by the filter). */
export function platformOf(
  type: string,
  id: string,
  pkgPlatforms: Record<string, string>,
  platform: VizConfig["platform"],
): Platform {
  const rule = platform.types[type] ?? "neutral";
  if (rule === "hosts") return platform.hosts[basename(id)] ?? platform.hostDefault ?? "neutral";
  if (rule === "packages") return pkgPlatforms[basename(id)] ?? "both";
  return rule;
}

/** "owner/repo" display name from a githubRemoteUrl()-shaped URL. */
export function repoNameFromUrl(url: string | null): string | null {
  return url?.replace(/^https:\/\/github\.com\//, "") ?? null;
}

export function buildModel(raw: RawData): VizModel {
  const cfg = normalizeVizConfig(raw.cfg);
  const nodes = raw.nodes;
  const files = raw.files || {};
  const dirs = raw.dirs || {};
  const repoUrl = raw.repoUrl || null;
  const repoName = repoNameFromUrl(repoUrl);
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
  const typeOrder = cfg.taxonomy.types;
  const allTypes = [
    ...typeOrder.filter((t) => typeCounts[t]),
    ...Object.keys(typeCounts)
      .filter((t) => !typeOrder.includes(t))
      .sort(),
  ];

  // The profile keeps every type inside one top-level directory, so this is
  // normally unambiguous; if that's ever violated, the first concept of a
  // type fixes its group (deterministic, not "last write wins"). No
  // dir-groups configured -> no clusters at all (flat legend), not one big
  // "Other" bucket.
  const typeGroup: Record<string, string> = {};
  const groupTypes: Record<string, string[]> = {};
  let groupOrder: string[] = [];
  if (Object.keys(cfg.taxonomy.dirGroups).length) {
    for (const n of nodes) typeGroup[n.type] ??= cfg.taxonomy.dirGroups[dirOf(n.id)] ?? cfg.taxonomy.other;
    for (const t of allTypes) (groupTypes[typeGroup[t]!] ??= []).push(t);
    groupOrder = [
      ...cfg.taxonomy.groupOrder.filter((g) => groupTypes[g]),
      ...(groupTypes[cfg.taxonomy.other] ? [cfg.taxonomy.other] : []),
    ];
  }

  const pkgPlatforms = raw.pkgPlatforms ?? {};
  const platformById: Record<string, Platform> = {};
  for (const n of nodes) platformById[n.id] = platformOf(n.type, n.id, pkgPlatforms, cfg.platform);

  const radii = nodes.map((n) => (3.5 + Math.min(6.5, (deg[n.id] || 0) * 0.8)) * 0.42);

  return {
    nodes,
    files,
    dirs,
    repoUrl,
    repoName,
    cfg,
    displayName: displayName(cfg, repoName),
    platforms: cfg.platform.values,
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

export interface ConceptTree {
  node: ConceptNode;
  children: ConceptTree[];
}

/** BFS tree of `anchorId`'s neighborhood for the pinned sidebar listing.
 *  Each node attaches to exactly one parent — its alphabetically-first
 *  (title, then id) neighbor in the previous BFS layer — and siblings sort
 *  alphabetically, so every reachable node renders exactly once. Invisible
 *  nodes are spliced out with their visible descendants promoted to the
 *  nearest visible ancestor. The anchor is always included, even when it
 *  fails `visible` (it is the selection context). Unknown anchor -> null. */
export function conceptTree(
  model: VizModel,
  anchorId: string,
  depth: 1 | 2,
  visible: (n: ConceptNode) => boolean,
): ConceptTree | null {
  const anchor = model.byId[anchorId];
  if (!anchor) return null;
  const byTitle = (a: ConceptNode, b: ConceptNode) => a.title.localeCompare(b.title) || a.id.localeCompare(b.id);

  const layer = new Map<string, number>([[anchorId, 0]]);
  const kids = new Map<string, ConceptNode[]>();
  let frontier = [anchorId];
  for (let d = 1; d <= depth; d++) {
    const next: string[] = [];
    for (const cur of frontier) {
      for (const nb of model.adjById[cur] ?? []) {
        if (!layer.has(nb)) {
          layer.set(nb, d);
          next.push(nb);
        }
      }
    }
    for (const id of next) {
      const parent = [...(model.adjById[id] ?? [])]
        .filter((p) => layer.get(p) === d - 1)
        .map((p) => model.byId[p]!)
        .sort(byTitle)[0]!;
      const list = kids.get(parent.id);
      if (list) list.push(model.byId[id]!);
      else kids.set(parent.id, [model.byId[id]!]);
    }
    frontier = next;
  }

  // An invisible child is spliced out and its visible descendants promoted
  // into this sibling list; the final sort keeps siblings alphabetical even
  // after promotion merges two generations.
  const build = (id: string): ConceptTree[] => {
    const out: ConceptTree[] = [];
    for (const c of kids.get(id) ?? []) {
      if (visible(c)) out.push({ node: c, children: build(c.id) });
      else out.push(...build(c.id));
    }
    return out.sort((a, b) => byTitle(a.node, b.node));
  };
  return { node: anchor, children: build(anchorId) };
}

/** Ids rendered by a conceptTree: the anchor plus every emitted row. */
export function treeIds(t: ConceptTree): Set<string> {
  const ids = new Set<string>();
  const walk = (n: ConceptTree) => {
    ids.add(n.node.id);
    n.children.forEach(walk);
  };
  walk(t);
  return ids;
}

export function loadFromDom(): VizModel {
  return buildModel(JSON.parse(document.getElementById("data")!.textContent!));
}
