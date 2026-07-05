// Shared vocabulary for the per-type scaffold passes (modules.ts, hosts.ts,
// packages.ts, nvim.ts): repo file access rooted at ctx.root, plus the
// darwin/nixos class constants the module and host passes both speak.
// Everything else each pass needs comes from the injected ScaffoldContext
// (okf-scaffold-api.d.ts, vendored from okflight).

import { readdirSync, readFileSync, statSync, type Stats } from "node:fs";
import { join } from "node:path";
import type { ScaffoldContext } from "./okf-scaffold-api";

export const CLASSES = ["darwin", "nixos"] as const;
export type ClassName = (typeof CLASSES)[number];
export const CLASS_LABEL: Record<ClassName, string> = { darwin: "darwin", nixos: "NixOS" };
export const docType = (cls: ClassName) => (cls === "darwin" ? "Darwin Module" : "NixOS Module");
export const classTag = (cls: ClassName) => `${cls}-module`;

/** Repo file access shared by every pass — all paths repo-relative. */
export interface Repo {
  read(rel: string): string;
  /** Non-hidden, non-`_` entries of a directory, sorted. */
  nixFiles(dir: string): string[];
  exists(rel: string): boolean;
  /** Stats or undefined — never throws (dangling symlinks stat to undefined). */
  stat(rel: string): Stats | undefined;
}

export function repoOf(ctx: ScaffoldContext): Repo {
  const abs = (rel: string) => join(ctx.root, rel);
  return {
    read: (rel) => readFileSync(abs(rel), "utf8"),
    nixFiles: (dir) =>
      readdirSync(abs(dir))
        .filter((f) => !f.startsWith("_") && !f.startsWith("."))
        .sort(),
    exists: (rel) => statSync(abs(rel), { throwIfNoEntry: false }) !== undefined,
    stat: (rel) => statSync(abs(rel), { throwIfNoEntry: false }),
  };
}
