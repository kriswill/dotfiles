// Deterministic 3D force-directed layout, run once at generation time — the
// viewer renders frozen positions (the codebase-memory-mcp approach: its C
// layout3d computes server-side and the UI never simulates). 63 nodes needs
// no Barnes-Hut; plain O(n²) repulsion converges in milliseconds.

export interface P3 { x: number; y: number; z: number }

export function layout3d(ids: string[], edges: { s: string; t: string }[]): Map<string, P3> {
  const n = ids.length;
  const index = new Map(ids.map((id, i) => [id, i]));
  const pos = new Float64Array(n * 3);
  const vel = new Float64Array(n * 3);

  // Deterministic init: golden-spiral points on growing spheres (no RNG).
  const GA = Math.PI * (3 - Math.sqrt(5));
  for (let i = 0; i < n; i++) {
    const r = 30 * Math.cbrt(i + 1);
    const y = 1 - (2 * (i + 0.5)) / n;
    const rad = Math.sqrt(1 - y * y);
    const th = GA * i;
    pos[i * 3] = Math.cos(th) * rad * r;
    pos[i * 3 + 1] = y * r;
    pos[i * 3 + 2] = Math.sin(th) * rad * r;
  }

  const springs = edges
    .map((e) => [index.get(e.s)!, index.get(e.t)!] as const)
    .filter(([a, b]) => a !== undefined && b !== undefined && a !== b);

  const REST = 110;
  let alpha = 1;
  for (let iter = 0; iter < 900; iter++) {
    for (let i = 0; i < n; i++) {
      for (let j = i + 1; j < n; j++) {
        let dx = pos[i * 3] - pos[j * 3];
        let dy = pos[i * 3 + 1] - pos[j * 3 + 1];
        let dz = pos[i * 3 + 2] - pos[j * 3 + 2];
        const d2 = dx * dx + dy * dy + dz * dz || 1;
        if (d2 < 400 * 400) {
          const f = 5200 / d2;
          dx *= f; dy *= f; dz *= f;
          vel[i * 3] += dx; vel[i * 3 + 1] += dy; vel[i * 3 + 2] += dz;
          vel[j * 3] -= dx; vel[j * 3 + 1] -= dy; vel[j * 3 + 2] -= dz;
        }
      }
    }
    for (const [a, b] of springs) {
      const dx = pos[b * 3] - pos[a * 3];
      const dy = pos[b * 3 + 1] - pos[a * 3 + 1];
      const dz = pos[b * 3 + 2] - pos[a * 3 + 2];
      const d = Math.sqrt(dx * dx + dy * dy + dz * dz) || 1;
      const f = ((d - REST) * 0.006) / d;
      vel[a * 3] += dx * f; vel[a * 3 + 1] += dy * f; vel[a * 3 + 2] += dz * f;
      vel[b * 3] -= dx * f; vel[b * 3 + 1] -= dy * f; vel[b * 3 + 2] -= dz * f;
    }
    for (let i = 0; i < n; i++) {
      vel[i * 3] -= pos[i * 3] * 0.004;
      vel[i * 3 + 1] -= pos[i * 3 + 1] * 0.004;
      vel[i * 3 + 2] -= pos[i * 3 + 2] * 0.004;
      pos[i * 3] += vel[i * 3] * alpha;
      pos[i * 3 + 1] += vel[i * 3 + 1] * alpha;
      pos[i * 3 + 2] += vel[i * 3 + 2] * alpha;
      vel[i * 3] *= 0.6; vel[i * 3 + 1] *= 0.6; vel[i * 3 + 2] *= 0.6;
    }
    alpha = Math.max(alpha * 0.995, 0.01);
  }

  // Normalize to a ~260-unit bounding radius so the camera fit is predictable.
  let maxR = 1;
  for (let i = 0; i < n; i++) {
    const r = Math.hypot(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2]);
    if (r > maxR) maxR = r;
  }
  const k = 260 / maxR;
  const out = new Map<string, P3>();
  ids.forEach((id, i) => {
    out.set(id, {
      x: +(pos[i * 3] * k).toFixed(2),
      y: +(pos[i * 3 + 1] * k).toFixed(2),
      z: +(pos[i * 3 + 2] * k).toFixed(2),
    });
  });
  return out;
}
