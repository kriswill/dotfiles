---
name: html-doc
description: Author or edit a standalone HTML document (a runbook, operator's manual, report, or reference page meant to be opened directly in a browser rather than served by an app). Applies the house dark/light theme, seeded from the system preference, with a persisted icon toggle. Use whenever writing a .html file that a person will read, including edits to an existing one that lacks the theme.
---

# Standalone HTML documents

Every standalone HTML document gets a dark/light theme. It starts from the
reader's system preference and can be flipped with an icon toggle, whose choice
persists. These documents are read on whatever machine and at whatever hour,
and a hardcoded white page is a real irritation at night.

There is no visible "auto" mode: the system preference seeds the initial value
and is never shown as a state the reader selects. Do not add one.

This is not optional and not something to ask about -- apply it by default.

## What to do

1. Read `assets/theme.html`.
2. Copy its three fragments into the document **verbatim**:
   - **Fragment 1** into `<style>`, at the top.
   - **Fragment 2** into `<head>`, after `</style>`. It must be in `<head>`.
   - **Fragment 3** as the first thing inside `<body>`.
3. Make every colour in the document resolve through a `var(--...)` from
   fragment 1. A hardcoded hex anywhere else is the bug this skill exists to
   prevent -- it will look correct in one theme and wrong in the other.

Do not retype the fragments from memory or reimplement the toggle. Copying is
the entire point: it is what makes two documents written months apart behave
the same way.

## Inline SVG diagrams

If the document embeds an SVG, give the `<svg>` an id and scope every rule in its
`<style>` to that id (`#diagram .box { ... }`). A stylesheet inside inline SVG is
**not** scoped to the SVG -- bare `.box` or `text` selectors leak into the whole
page. Map the diagram's own variables onto the page palette on that id, so the
theme toggle drives the diagram too:

```css
#diagram { --fg: var(--ink); --line: var(--rule); --box: var(--bg); }
```

Do not map a variable to itself (`--muted: var(--muted)`) -- that is a cycle and
resolves to nothing. If the diagram and the page already use the same name, just
let it inherit.

Never write a literal `style` tag inside a CSS comment in that stylesheet. The
parser treats it as a real element even inside `/* ... */`, which nests a second
stylesheet, silently drops every rule after it, and paints the diagram in initial
black. The balanced-tag check in the verifier below catches exactly this.

## Adding colours

If the document needs a colour the palette lacks, add it to **all three**
blocks in fragment 1 (`:root`, the `prefers-color-scheme` block, and
`:root[data-theme="dark"]`). A variable defined in only one block silently
falls back to the light value.

## Inline code and tables

Two rough edges show up in almost every document and neither is visible until a
browser lays the text out.

**A short code token must never split across lines.** `.viz-root` broken after
the hyphen renders as two separately-boxed fragments and reads as two different
identifiers. Default inline code to `nowrap`, and keep `box-decoration-break`
for the rare token that still has to wrap:

```css
  code {
    white-space: nowrap;
    -webkit-box-decoration-break: clone;
    box-decoration-break: clone;
  }
  /* Escape hatch: a long path or URL in a narrow column, where wrapping beats
     overflowing. Opt in per element -- never make this the default.
     An ATTRIBUTE, not a class: `.wrap` is the most common name for a page
     container, and `<code class="wrap">` would silently inherit its
     max-width/margin/padding and render as a huge centred block. */
  code[data-wrap] { white-space: normal; overflow-wrap: anywhere; }
  /* Let the CELL rewrap around a wide token instead of stretching the table. */
  th, td { overflow-wrap: break-word; }
```

Rule of thumb: a token over ~24 characters in a table cell or a narrow grid
column gets `<code data-wrap>`. Everything shorter stays whole.

More generally: **a single-word utility class on an inline element is a
collision waiting to happen** -- `wrap`, `box`, `note`, `code` are all in use
as layout classes somewhere. Use an attribute or a namespaced name.

**Give a multi-column table explicit widths** when its columns hold different
kinds of content (a short key beside two prose columns). Left to itself the
browser sizes columns from content and produces ragged, uneven wrapping:

```html
<colgroup><col style="width:24%"><col style="width:34%"><col></colgroup>
```

Neither of these is machine-checkable -- they are what you look for when you
render the document (see below).

## Verify before reporting done

Run this against the finished file. It catches the three failure modes that
are invisible on a light-mode screen -- a colour that bypassed the palette, a
variable missing from a theme, and a script that does not parse:

```sh
bun -e '
const f = process.argv[1];
const html = await Bun.file(f).text();
const blocks = [...html.matchAll(/(:root(?:\[data-theme="dark"\]|:not\(\[data-theme="light"\]\))?)\s*\{([^}]*)\}/g)];
const sets = blocks.map(([, sel, body]) => [sel, new Set([...body.matchAll(/--([a-z-]+):/g)].map(m => m[1]))]);
const all = new Set(sets.flatMap(([, s]) => [...s]));
for (const [sel, s] of sets) {
  const missing = [...all].filter(v => !s.has(v));
  console.log(`${missing.length ? "FAIL" : "ok  "} ${sel} (${s.size} vars)` + (missing.length ? ` missing: ${missing}` : ""));
}
if (sets.length !== 3) console.log(`FAIL expected 3 palette blocks, found ${sets.length}`);
const used = new Set([...html.matchAll(/var\(--([a-z-]+)\)/g)].map(m => m[1]));
const undef = [...used].filter(v => !all.has(v));
console.log(undef.length ? `FAIL undefined vars: ${undef}` : "ok   no undefined vars");
const style = (html.match(/<style>([\s\S]*?)<\/style>/) || [, ""])[1];
const stray = [...style.matchAll(/#[0-9a-fA-F]{3,8}\b/g)].length - [...blocks].reduce((n, [, , b]) => n + [...b.matchAll(/#[0-9a-fA-F]{3,8}\b/g)].length, 0);
console.log(stray > 0 ? `FAIL ${stray} hardcoded colour(s) outside the palette` : "ok   no hardcoded colours");
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
scripts.forEach((s, i) => { try { new Function(s); console.log(`ok   script ${i + 1} parses`); } catch (e) { console.log(`FAIL script ${i + 1}: ${e.message}`); } });
if (!/<head>[\s\S]*localStorage.getItem\("theme"\)[\s\S]*<\/head>/.test(html)) console.log("FAIL fragment 2 is not in <head> -- will flash the wrong theme");
else console.log("ok   fragment 2 is in <head>");
console.log(/Theme: Auto|removeAttribute\("data-theme"\)/.test(html) ? "FAIL an auto state survives -- the theme must always be explicit" : "ok   no auto state");
const so = (html.match(/<style>/g) || []).length, sc = (html.match(/<\/style>/g) || []).length;
console.log(so === sc ? "ok   style tags balanced" : `FAIL ${so} <style> vs ${sc} </style> -- a literal style tag inside a stylesheet or SVG comment`);
' <file.html>
```

Every line must read `ok`.

The verifier checks colour and script, not layout. **Open or screenshot the
finished document and look at it** -- in both themes -- for the things it
cannot see:

- inline code split across a line break (see above);
- an element that inherited styling from a class it did not mean to share --
  the symptom is a small inline thing rendering huge, centred, or overlapping;
- a table column so narrow it wraps every cell to three lines, or one so wide
  it leaves the others cramped;
- text overlapping shapes, or spilling past a `viewBox`, in any inline SVG;
- anything that reads correctly in one theme and wrongly in the other.

## Why the theme is shaped the way it is

The rationale for each design choice -- why the theme is always explicit, why
source order matters, why the icon shows the theme you would switch to -- is in
the comment header of `assets/theme.html`. Read it before changing anything
there.
