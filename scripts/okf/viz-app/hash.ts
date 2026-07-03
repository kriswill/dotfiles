// URL-hash codec for viewer selections:
// `c/<concept-id>` | `f/<file-path>` | `d/<dir-path>`.
// Pure — validation against the data model is injected by the caller.

export type Selection =
  | { kind: "none" }
  | { kind: "concept"; id: string }
  | { kind: "file"; path: string }
  | { kind: "dir"; path: string };

export interface HashModel {
  byId: Record<string, unknown>;
  files: Record<string, unknown>;
  dirs: Record<string, unknown>;
}

export function encodeHash(sel: Selection): string {
  // '%' is the one character that breaks the decode round-trip — escape it so
  // ids/paths containing it survive the URL. Browsers pass other fragment
  // chars through (or add %XX that decodeURIComponent restores).
  const enc = (s: string) => s.replace(/%/g, "%25");
  if (sel.kind === "concept") return "c/" + enc(sel.id);
  if (sel.kind === "file") return "f/" + enc(sel.path);
  if (sel.kind === "dir") return "d/" + enc(sel.path);
  return "";
}

export function decodeHash(raw: string, model: HashModel): Selection {
  let h: string;
  try {
    h = decodeURIComponent(raw.replace(/^#/, ""));
  } catch {
    return { kind: "none" }; // stray '%' in a hand-edited or truncated link
  }
  if (h.startsWith("c/") && model.byId[h.slice(2)]) return { kind: "concept", id: h.slice(2) };
  if (h.startsWith("f/") && model.files[h.slice(2)]) return { kind: "file", path: h.slice(2) };
  if (h.startsWith("d/") && model.dirs[h.slice(2)]) return { kind: "dir", path: h.slice(2) };
  return { kind: "none" };
}
