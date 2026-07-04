// Theme stops: light and dark. Each stop is a complete CSS custom-property
// set applied inline on :root — inline wins over the prefers-color-scheme
// media block in the shell, so a chosen theme overrides the OS scheme. The
// shell's :root light/dark blocks (the un-picked defaults) are generated
// from the "light" and "dark" stops at build time — viz.ts imports THEMES —
// so they can never drift.
//
// The 12 categorical slots (--s1..--s12, mapped by data.ts TYPE_ORDER) were
// optimized per surface against the dataviz six checks and PASS all-pairs
// CVD separation (Machado protan/deutan ΔE ≥ 15 worst pair, target 12) with
// hue families frozen as identity anchors. Sub-3:1 contrast entries are the
// validator's documented relief case — node labels, legend text, and
// tooltips carry identity alongside color. `gen` feeds viz-app/color.ts for
// types beyond the curated slots.

import type { GenParams } from "./color";

export interface ThemeDef {
  name: string;
  vars: Record<string, string>;
  gen: GenParams;
}

export const THEMES: ThemeDef[] = [
  {
    name: "light",
    gen: { l: 0.55, c: 0.13 },
    vars: {
      "--surface-1": "#faf9f4", "--page": "#f3f2ec",
      "--ink-1": "#0b0b0b", "--ink-2": "#52514e", "--ink-muted": "#898781",
      "--grid": "#ddddd3", "--baseline": "#c0bfb2",
      "--link": "#256abf",
      "--tok-c": "#898781", "--tok-s": "#0b7a4e", "--tok-k": "#4a3aa7", "--tok-n": "#9a5b00",
      "--s1": "#4478bc", "--s2": "#009766", "--s3": "#d38f00", "--s4": "#056b00",
      "--s5": "#5041ae", "--s6": "#c54b46", "--s7": "#e9709e", "--s8": "#e66e41",
      "--s9": "#2fbbb9", "--s10": "#51abd7", "--s11": "#87b46f", "--s12": "#6c4686",
    },
  },
  {
    name: "dark",
    gen: { l: 0.6, c: 0.13 },
    vars: {
      "--surface-1": "#1a1a19", "--page": "#0d0d0d",
      "--ink-1": "#ffffff", "--ink-2": "#c3c2b7", "--ink-muted": "#898781",
      "--grid": "#2c2c2a", "--baseline": "#383835",
      "--link": "#6da7ec",
      "--tok-c": "#898781", "--tok-s": "#2fbe8b", "--tok-k": "#9085e9", "--tok-n": "#d99a1f",
      "--s1": "#1481f3", "--s2": "#46a87f", "--s3": "#c68413", "--s4": "#007600",
      "--s5": "#857dd3", "--s6": "#ad4b4b", "--s7": "#b31d60", "--s8": "#cb5e36",
      "--s9": "#16a295", "--s10": "#359eba", "--s11": "#81a05a", "--s12": "#77569b",
    },
  },
];

/** Index the toggle rests at when the user hasn't picked a theme. */
export const defaultThemeIndex = (dark: boolean) => (dark ? 1 : 0);

export function applyThemeVars(i: number) {
  if (typeof document === "undefined") return;
  const root = document.documentElement;
  for (const [k, v] of Object.entries(THEMES[i]!.vars)) root.style.setProperty(k, v);
}
