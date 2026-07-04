// URL-hash codec for viewer state. The selection is the path segment
// (`c/<concept-id>` | `f/<file-path>` | `d/<dir-path>`); view filters ride
// behind a `?` as query params (`hide=<type,type,…>` + `q=<search>` +
// `isolate=<1|2>`, the last only meaningful for a concept selection, + one
// `<facet-name>=<value>` param per configured facet), so a shared link
// reproduces the whole lens, not just the selection.
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
  /** Neighborhood isolation depth (0 = off); only meaningful for a concept selection. */
  isolate: 0 | 1 | 2;
  /** Facet name -> "all" (encodes to nothing) or one of that facet's values. */
  facets: Record<string, string>;
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
  /** Configured facets: names gate which query params decode, and each
   *  facet's values gate what its param decodes to (else "all"). */
  facets?: { name: string; values: string[] }[];
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

/** Canonical form: hidden types sorted, empty filters omitted entirely,
 *  facet params in `view.filters.facets`' own (caller-supplied) order. */
export function encodeViewHash(view: ViewState): string {
  const p = new URLSearchParams();
  // Type names contain no ','; the registry (okf-profile.md) keeps it that way.
  if (view.filters.hidden.length) p.set("hide", [...view.filters.hidden].sort().join(","));
  if (view.filters.q) p.set("q", view.filters.q);
  if (view.sel.kind === "concept" && view.filters.isolate) p.set("isolate", String(view.filters.isolate));
  for (const [name, v] of Object.entries(view.filters.facets)) if (v && v !== "all") p.set(name, v);
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
  const p = new URLSearchParams(qi >= 0 ? bare.slice(qi + 1) : "");
  const hide = p.get("hide");
  const hidden = hide ? hide.split(",").filter((t) => t && (!model.typeCounts || t in model.typeCounts)) : [];
  const q = p.get("q") ?? "";
  const iv = p.get("isolate");
  const isolate: 0 | 1 | 2 = sel.kind !== "concept" ? 0 : iv === "1" ? 1 : iv === "2" ? 2 : 0;
  const facets: Record<string, string> = {};
  for (const f of model.facets ?? []) {
    // Legacy alias: pre-facets links used `os=`. Read it only for a facet
    // literally named "platform" and only when `platform=` itself is
    // absent — encode never emits `os=` again, so this is read-only.
    const v = p.get(f.name) ?? (f.name === "platform" && !p.has("platform") ? p.get("os") : null);
    facets[f.name] = v && f.values.includes(v) ? v : "all";
  }
  return { sel, filters: { hidden, q, isolate, facets } };
}
