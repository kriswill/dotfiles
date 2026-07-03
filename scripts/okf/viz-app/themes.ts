// Theme stops for the sidebar slider: light → medium → dark → black. Each
// stop is a complete CSS custom-property set applied inline on :root —
// inline wins over the prefers-color-scheme media block in the shell, so a
// chosen theme overrides the OS scheme. "light" and "black" must stay
// byte-identical to the shell's :root light/dark blocks in
// scripts/okf/viz.ts (they are the un-picked defaults). Node palettes are
// tuned per background: deep on paper/grey, bright on dark — the scene also
// switches render mode by background luminance (scene.ts).

export interface ThemeDef {
  name: string;
  vars: Record<string, string>;
}

export const THEMES: ThemeDef[] = [
  {
    name: "light",
    vars: {
      "--surface-1": "#faf9f4", "--page": "#f3f2ec",
      "--ink-1": "#0b0b0b", "--ink-2": "#52514e", "--ink-muted": "#898781",
      "--grid": "#ddddd3", "--baseline": "#c0bfb2",
      "--link": "#256abf",
      "--tok-c": "#898781", "--tok-s": "#0b7a4e", "--tok-k": "#4a3aa7", "--tok-n": "#9a5b00",
      "--s1": "#1e6bc8", "--s2": "#12996a", "--s3": "#d18e00", "--s4": "#0a7500",
      "--s5": "#4a3aa7", "--s6": "#d83c3b", "--s7": "#d76490", "--s8": "#dd5a25",
      "--s-other": "#898781",
    },
  },
  {
    name: "medium",
    vars: {
      "--surface-1": "#94948f", "--page": "#8b8b86",
      "--ink-1": "#101010", "--ink-2": "#26261f", "--ink-muted": "#3f3f39",
      "--grid": "#7b7b75", "--baseline": "#686862",
      "--link": "#0e3a74",
      "--tok-c": "#3f3f39", "--tok-s": "#073f27", "--tok-k": "#2b2168", "--tok-n": "#5c3d05",
      "--s1": "#1f5fae", "--s2": "#12805a", "--s3": "#b57a00", "--s4": "#0c6410",
      "--s5": "#3b2d8f", "--s6": "#c03231", "--s7": "#c25682", "--s8": "#c14e20",
      "--s-other": "#43423d",
    },
  },
  {
    name: "dark",
    vars: {
      "--surface-1": "#3e3e3b", "--page": "#333331",
      "--ink-1": "#f2f2ef", "--ink-2": "#c9c8c0", "--ink-muted": "#97958e",
      "--grid": "#4d4d49", "--baseline": "#5b5a54",
      "--link": "#8db6ee",
      "--tok-c": "#97958e", "--tok-s": "#3fc493", "--tok-k": "#a29af0", "--tok-n": "#dda531",
      "--s1": "#3987e5", "--s2": "#199e70", "--s3": "#c98500", "--s4": "#008300",
      "--s5": "#9085e9", "--s6": "#e66767", "--s7": "#d55181", "--s8": "#d95926",
      "--s-other": "#a3a19a",
    },
  },
  {
    name: "black",
    vars: {
      "--surface-1": "#1a1a19", "--page": "#0d0d0d",
      "--ink-1": "#ffffff", "--ink-2": "#c3c2b7", "--ink-muted": "#898781",
      "--grid": "#2c2c2a", "--baseline": "#383835",
      "--link": "#6da7ec",
      "--tok-c": "#898781", "--tok-s": "#2fbe8b", "--tok-k": "#9085e9", "--tok-n": "#d99a1f",
      "--s1": "#3987e5", "--s2": "#199e70", "--s3": "#c98500", "--s4": "#008300",
      "--s5": "#9085e9", "--s6": "#e66767", "--s7": "#d55181", "--s8": "#d95926",
      "--s-other": "#898781",
    },
  },
];

/** Index the slider rests at when the user hasn't picked a theme. */
export const defaultThemeIndex = (dark: boolean) => (dark ? 3 : 0);

export function applyThemeVars(i: number) {
  if (typeof document === "undefined") return;
  const root = document.documentElement;
  for (const [k, v] of Object.entries(THEMES[i]!.vars)) root.style.setProperty(k, v);
}
