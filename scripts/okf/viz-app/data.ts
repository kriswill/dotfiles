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
}

export interface RawData {
  nodes: ConceptNode[];
  edges: { s: string; t: string }[];
  files?: Record<string, EmbeddedFile>;
}

export interface VizModel {
  nodes: ConceptNode[];
  files: Record<string, EmbeddedFile>;
  byId: Record<string, ConceptNode>;
  indexOf: Map<string, number>;
  edges: { s: string; t: string }[];
  edgeIdx: [number, number][];
  deg: Record<string, number>;
  inLinks: Record<string, string[]>;
  typeCounts: Record<string, number>;
  allTypes: string[];
  /** Scene sphere radius per node (same order as nodes). */
  radii: number[];
}

// Fixed palette slot order (never cycled); overflow types fold into muted "Other".
export const TYPE_ORDER = [
  "Darwin Module",
  "Nix Package",
  "Playbook",
  "Pattern",
  "Decision",
  "Host",
  "Sub-flake",
  "Flake-parts Module",
];

export function buildModel(raw: RawData): VizModel {
  const nodes = raw.nodes;
  const files = raw.files || {};
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

  const radii = nodes.map((n) => (3.5 + Math.min(6.5, (deg[n.id] || 0) * 0.8)) * 0.42);

  return { nodes, files, byId, indexOf, edges, edgeIdx, deg, inLinks, typeCounts, allTypes, radii };
}

export function loadFromDom(): VizModel {
  return buildModel(JSON.parse(document.getElementById("data")!.textContent!));
}
