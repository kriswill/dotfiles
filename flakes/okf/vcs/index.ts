// Workspace discovery + provider factory. Today git-only: the root is the
// git toplevel of the caller's cwd (matching okf's original behavior); the
// okf.toml walk-up and the "none" provider land with `[vcs] provider`.

import { gitProvider, gitRoot } from "./git";
import type { VcsProvider } from "./types";

export type { VcsProvider };

/** Discover the workspace root and construct its provider; exits 1 with
 *  guidance when no workspace is found. */
export function discoverVcs(): VcsProvider {
  const root = gitRoot();
  if (!root) {
    console.error("okf: not inside a git repository — run from the repo the bundle lives in");
    process.exit(1);
  }
  return gitProvider(root);
}
