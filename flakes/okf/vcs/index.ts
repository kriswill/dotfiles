// Provider factory + git-root probe. Workspace-root discovery itself lives
// in config-cli.ts (nearest okf.toml up from cwd wins, else the git
// toplevel) because the config file names are its domain; this module turns
// a chosen root into a provider.

import { realpathSync } from "node:fs";
import { gitProvider, gitRoot } from "./git";
import { noneProvider } from "./none";
import type { VcsProvider } from "./types";

export { gitRoot };
export type { VcsProvider };

/**
 * Construct the provider for a workspace root. "auto" picks git when the
 * root IS a git toplevel (the git provider's batched `git log`/`ls-files`
 * paths are toplevel-relative, so a nested root would silently mis-key
 * every lookup), and falls back to the filesystem provider otherwise.
 * Explicit "git" on a non-toplevel root throws instead of degrading —
 * silent mtime timestamps would rewrite scaffolded dates on the next
 * --force run.
 */
export function createProvider(kind: "auto" | "git" | "none", root: string, ignore: string[]): VcsProvider {
  if (kind === "none") return noneProvider(root, ignore);
  const top = gitRoot(root);
  const same = top !== null && realpathSync(top) === realpathSync(root);
  if (same) return gitProvider(root);
  if (kind === "git")
    throw new Error(
      top
        ? `[vcs] provider = "git" but the workspace root (${root}) is not the git toplevel (${top})`
        : Bun.which("git")
          ? `[vcs] provider = "git" but ${root} is not inside a git repository`
          : `[vcs] provider = "git" but git is not installed (or not on PATH)`,
    );
  return noneProvider(root, ignore);
}
