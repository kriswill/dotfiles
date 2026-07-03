// URL-hash codec for viewer selections: `c/<concept-id>` | `f/<file-path>`.
// Pure — validation against the data model is injected by the caller.

export type Selection =
  | { kind: "none" }
  | { kind: "concept"; id: string }
  | { kind: "file"; path: string };

export interface HashModel {
  byId: Record<string, unknown>;
  files: Record<string, unknown>;
}

export function encodeHash(sel: Selection): string {
  if (sel.kind === "concept") return "c/" + sel.id;
  if (sel.kind === "file") return "f/" + sel.path;
  return "";
}

export function decodeHash(raw: string, model: HashModel): Selection {
  const h = decodeURIComponent(raw.replace(/^#/, ""));
  if (h.startsWith("c/") && model.byId[h.slice(2)]) return { kind: "concept", id: h.slice(2) };
  if (h.startsWith("f/") && model.files[h.slice(2)]) return { kind: "file", path: h.slice(2) };
  return { kind: "none" };
}
