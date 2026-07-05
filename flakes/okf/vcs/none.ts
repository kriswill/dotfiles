// The no-VCS provider: plain-filesystem workspaces (any directory with an
// okf.toml). Tracked files = an fs walk minus junk dirs and the configured
// `[vcs] ignore` globs; timestamps = file mtime; no revision citations, no
// remote. Symlinks are skipped entirely (cycle safety, determinism).

import { readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import type { VcsProvider } from "./types";

/** Directory/file names skipped at any depth, before user globs apply. */
const SKIP_NAMES = new Set([".git", ".hg", ".svn", ".jj", "node_modules", ".direnv", ".DS_Store"]);

const iso = (ms: number) => new Date(ms).toISOString().replace(/\.\d{3}Z$/, "+00:00");

export function noneProvider(root: string, ignore: string[] = []): VcsProvider {
  const globs = ignore.map((g) => new Bun.Glob(g));
  const ignored = (rel: string) => globs.some((g) => g.match(rel));

  let cache: string[] | null = null;
  const walk = (): string[] => {
    const out: string[] = [];
    const rec = (dirAbs: string, rel: string) => {
      for (const e of readdirSync(dirAbs, { withFileTypes: true })) {
        if (SKIP_NAMES.has(e.name)) continue;
        const r = rel ? `${rel}/${e.name}` : e.name;
        if (ignored(r)) continue;
        if (e.isDirectory()) rec(join(dirAbs, e.name), r);
        else if (e.isFile()) out.push(r);
      }
    };
    rec(root, "");
    return out.sort();
  };

  return {
    name: "none",
    root,
    revisionPattern: null,

    trackedFiles(): string[] {
      return (cache ??= walk());
    },

    lastModified(path: string): string | null {
      const st = statSync(join(root, path.replace(/\/$/, "")), { throwIfNoEntry: false });
      if (st?.isFile()) return iso(st.mtimeMs);
      if (st?.isDirectory()) {
        // Newest tracked file under the prefix, mirroring the git provider's
        // directory semantics.
        const prefix = path.endsWith("/") ? path : path + "/";
        let max = -1;
        for (const f of cache ?? (cache = walk())) {
          if (!f.startsWith(prefix)) continue;
          const s = statSync(join(root, f), { throwIfNoEntry: false });
          if (s && s.mtimeMs > max) max = s.mtimeMs;
        }
        return max >= 0 ? iso(max) : null;
      }
      return null;
    },

    resolveRevisions(): Record<string, string> {
      return {};
    },

    remoteUrl(): string | null {
      return null;
    },
  };
}
