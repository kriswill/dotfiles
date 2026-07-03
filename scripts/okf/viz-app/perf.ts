// Startup instrumentation: performance.mark wrappers + a summary exposed on
// window.__okf.perf (read by `okf viz --perf` via headless Chrome).

export const MARKS = ["viz:parse", "viz:mount", "viz:scene-init", "viz:first-frame", "viz:interactive"] as const;

export function mark(name: (typeof MARKS)[number]) {
  if (typeof performance !== "undefined") performance.mark(name);
}

export interface PerfEntry {
  name: string;
  ms: number;
}

/** Mark times in ms since navigation start, in chronological order. */
export function summary(): PerfEntry[] {
  if (typeof performance === "undefined") return [];
  return performance
    .getEntriesByType("mark")
    .filter((m) => m.name.startsWith("viz:"))
    .map((m) => ({ name: m.name, ms: Math.round(m.startTime * 10) / 10 }))
    .sort((a, b) => a.ms - b.ms);
}

export function installPerf(okf: Record<string, unknown>) {
  okf.perf = { summary, mark };
}
