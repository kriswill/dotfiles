// Git provider — the batched one-spawn implementations moved verbatim from
// lib.ts (a per-file `git log` spawn dominated viz/scaffold build time before
// they were batched; keep it that way).

import { spawnSync } from "node:child_process";
import type { VcsProvider } from "./types";

/** Toplevel of the git repository containing cwd, or null (not a repo / no
 *  git binary). Never exits — discovery (vcs/index.ts) owns the messaging. */
export function gitRoot(): string | null {
  const r = spawnSync("git", ["rev-parse", "--show-toplevel"], { encoding: "utf8" });
  if (r.error || r.status !== 0) return null;
  const root = (r.stdout ?? "").trim();
  return root || null;
}

/** Normalize any common git remote spelling to a https web URL:
 *  https://host/path(.git), git@host:path(.git), ssh://git@host/path(.git)
 *  -> https://host/path. Unrecognized shapes yield null (set `[vcs] url`). */
export function normalizeRemoteUrl(raw: string): string | null {
  const s = raw.trim();
  let m = s.match(/^https?:\/\/(?:[^@/]+@)?([^/]+)\/(.+?)(?:\.git)?\/?$/);
  if (m) return `https://${m[1]}/${m[2]}`;
  m = s.match(/^ssh:\/\/(?:[^@/]+@)?([^/:]+)(?::\d+)?\/(.+?)(?:\.git)?\/?$/);
  if (m) return `https://${m[1]}/${m[2]}`;
  m = s.match(/^[^@/]+@([^/:]+):(.+?)(?:\.git)?\/?$/);
  if (m) return `https://${m[1]}/${m[2]}`;
  return null;
}

export function gitProvider(root: string): VcsProvider {
  // One batched `git log --name-only` pass (newest first) instead of a git
  // subprocess per lastModified() call.
  let dates: Map<string, string> | null = null;
  const loadDates = (): Map<string, string> => {
    const map = new Map<string, string>();
    const r = spawnSync("git", ["-c", "core.quotepath=off", "log", "--format=%x00%cI", "--name-only"], {
      cwd: root,
      encoding: "utf8",
      maxBuffer: 64 * 1024 * 1024,
    });
    let date = "";
    for (const line of (r.stdout ?? "").split("\n")) {
      if (line.charCodeAt(0) === 0) date = line.slice(1); // NUL from %x00 marks a commit line
      else if (line && !map.has(line)) map.set(line, date); // first hit = newest
    }
    return map;
  };

  return {
    name: "git",
    root,

    // The profile's citation convention: backticked 7-40 char hex spans.
    revisionPattern: /`([0-9a-f]{7,40})`/g,

    trackedFiles(): string[] {
      const r = spawnSync("git", ["-c", "core.quotepath=off", "ls-files"], {
        cwd: root,
        encoding: "utf8",
        maxBuffer: 64 * 1024 * 1024,
      });
      return (r.stdout ?? "").split("\n").filter(Boolean);
    },

    lastModified(path: string): string | null {
      dates ??= loadDates();
      const exact = dates.get(path);
      if (exact) return exact;
      // Directories never appear in --name-only output — take the newest
      // file under the prefix (the map preserves newest-first insertion).
      const prefix = path.endsWith("/") ? path : path + "/";
      for (const [k, d] of dates) if (k.startsWith(prefix)) return d;
      return null;
    },

    resolveRevisions(candidates: string[]): Record<string, string> {
      if (!candidates.length) return {};
      const r = spawnSync("git", ["cat-file", "--batch-check"], {
        cwd: root,
        encoding: "utf8",
        input: candidates.map((c) => `${c}^{commit}`).join("\n"),
        maxBuffer: 16 * 1024 * 1024,
      });
      // One output line per input line, order preserved: `<oid> commit <size>`
      // on success, `<input> missing|ambiguous` otherwise.
      const lines = (r.stdout ?? "").trimEnd().split("\n");
      const out: Record<string, string> = {};
      candidates.forEach((c, i) => {
        const parts = (lines[i] ?? "").split(" ");
        if (parts[1] === "commit") out[c] = parts[0];
      });
      return out;
    },

    remoteUrl(): string | null {
      const r = spawnSync("git", ["remote", "get-url", "origin"], { cwd: root, encoding: "utf8" });
      if (r.error || r.status !== 0) return null;
      return normalizeRemoteUrl((r.stdout ?? "").trim());
    },
  };
}
