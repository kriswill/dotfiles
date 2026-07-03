// Stable generated colors for concept types beyond the curated TYPE_ORDER
// slots: FNV-1a hash of the type name → golden-angle hue, rendered in OKLCH
// at theme-tuned lightness/chroma. Pure function of (name, params), so a
// type keeps its color across regenerations and new types never repaint
// existing ones. Registered types should still be promoted into TYPE_ORDER —
// curated slots are validated for CVD separation; generated ones are not.

export interface GenParams {
  l: number;
  c: number;
}

const GOLDEN_ANGLE = 137.508;

function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

const lin2srgb = (c: number) => {
  c = Math.max(0, Math.min(1, c));
  return c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055;
};

export function oklchToHex(L: number, C: number, H: number): string {
  const h = (H * Math.PI) / 180;
  const a = C * Math.cos(h);
  const b = C * Math.sin(h);
  const l_ = L + 0.3963377774 * a + 0.2158037573 * b;
  const m_ = L - 0.1055613458 * a - 0.0638541728 * b;
  const s_ = L - 0.0894841775 * a - 1.291485548 * b;
  const l = l_ ** 3;
  const m = m_ ** 3;
  const s = s_ ** 3;
  const r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
  const g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
  const bb = -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s;
  const to = (v: number) =>
    Math.round(lin2srgb(v) * 255)
      .toString(16)
      .padStart(2, "0");
  return "#" + to(r) + to(g) + to(bb);
}

const cache = new Map<string, string>();

/** Deterministic color for a type name at the theme's lightness/chroma. */
export function nameColor(name: string, { l, c }: GenParams): string {
  const key = `${l}:${c}:${name}`;
  let hex = cache.get(key);
  if (!hex) {
    const hue = (fnv1a(name) * GOLDEN_ANGLE) % 360;
    hex = oklchToHex(l, c, hue);
    cache.set(key, hex);
  }
  return hex;
}
