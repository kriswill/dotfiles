// URL-hash codec for viewer state. The selection is the path segment
// (`c/<concept-id>` | `f/<file-path>` | `d/<dir-path>`); view filters ride
// behind a `?` as query params (`hide=<type,type,…>` + `q=<search>`), so a
// shared link reproduces the whole lens, not just the selection.
// Pure — validation against the data model is injected by the caller.

export type Selection =
  | { kind: "none" }
  | { kind: "concept"; id: string }
  | { kind: "file"; path: string }
  | { kind: "dir"; path: string };

export interface ViewFilters {
  /** Concept types toggled off in the legend. */
  hidden: string[];
  /** Search box contents. */
  q: string;
}

export interface ViewState {
  sel: Selection;
  filters: ViewFilters;
}

export interface HashModel {
  byId: Record<string, unknown>;
  files: Record<string, unknown>;
  dirs: Record<string, unknown>;
  /** When present, unknown types in `hide=` are dropped on decode. */
  typeCounts?: Record<string, number>;
}

// '%' breaks the decode round-trip and '?' would read as the filter
// separator — escape both so ids/paths containing them survive the URL.
// Browsers pass other fragment chars through (or add %XX that
// decodeURIComponent restores).
const enc = (s: string) => s.replace(/%/g, "%25").replace(/\?/g, "%3F");

export function encodeHash(sel: Selection): string {
  if (sel.kind === "concept") return "c/" + enc(sel.id);
  if (sel.kind === "file") return "f/" + enc(sel.path);
  if (sel.kind === "dir") return "d/" + enc(sel.path);
  return "";
}

/** Canonical form: hidden types sorted, empty filters omitted entirely. */
export function encodeViewHash(view: ViewState): string {
  const p = new URLSearchParams();
  // Type names contain no ','; the registry (okf-profile.md) keeps it that way.
  if (view.filters.hidden.length) p.set("hide", [...view.filters.hidden].sort().join(","));
  if (view.filters.q) p.set("q", view.filters.q);
  const qs = p.toString();
  return encodeHash(view.sel) + (qs ? "?" + qs : "");
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

export function decodeViewHash(raw: string, model: HashModel): ViewState {
  const bare = raw.replace(/^#/, "");
  const qi = bare.indexOf("?");
  const sel = decodeHash(qi < 0 ? bare : bare.slice(0, qi), model);
  const filters: ViewFilters = { hidden: [], q: "" };
  if (qi >= 0) {
    const p = new URLSearchParams(bare.slice(qi + 1));
    const hide = p.get("hide");
    if (hide) filters.hidden = hide.split(",").filter((t) => t && (!model.typeCounts || t in model.typeCounts));
    filters.q = p.get("q") ?? "";
  }
  return { sel, filters };
}
