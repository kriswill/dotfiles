// Build-side config loader — the single entry point every okf command uses.
// Reads the workspace's okf-viz.toml (optional; absent -> generic defaults),
// parses it with Bun.TOML, and normalizes STRICTLY: a malformed or misspelled
// config fails the command rather than silently running with wrong settings.
// Viewer sections are delegated to viz-app/config.ts's normalizeVizConfig;
// CLI-only sections (profile, vcs, scaffold, index) are consumed here as they
// land. Browser code never imports this file.

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { repoRoot } from "./lib";
import { normalizeVizConfig, VizConfigError, type VizConfig } from "./viz-app/config";

export const CONFIG_FILE = "okf-viz.toml";

export interface OkfConfig {
  viz: VizConfig;
}

export interface OkfContext {
  /** Absolute workspace root (the repo okf operates on). */
  root: string;
  /** Absolute bundle root: <root>/<viz.bundle.dir>. */
  bundle: string;
  cfg: OkfConfig;
}

let ctxCache: OkfContext | null = null;

/** Load (once per process) the workspace context: root, config, bundle path.
 *  Exits 1 on a malformed config — no command may run against a config it
 *  can't trust. Absent config file -> generic defaults. */
export function loadContext(): OkfContext {
  if (ctxCache) return ctxCache;
  const root = repoRoot();
  const cfgPath = join(root, CONFIG_FILE);
  let raw: unknown = {};
  if (existsSync(cfgPath)) {
    try {
      raw = Bun.TOML.parse(readFileSync(cfgPath, "utf8"));
    } catch (e) {
      console.error(`okf: cannot parse ${CONFIG_FILE} — ${e instanceof Error ? e.message : e}`);
      process.exit(1);
    }
  }
  let viz: VizConfig;
  try {
    viz = normalizeVizConfig(raw, { strict: true, warn: (m) => console.warn(`okf: warning: ${m}`) });
  } catch (e) {
    if (e instanceof VizConfigError) {
      console.error(`okf: ${e.message}`);
      process.exit(1);
    }
    throw e;
  }
  ctxCache = { root, bundle: join(root, viz.bundle.dir), cfg: { viz } };
  return ctxCache;
}
