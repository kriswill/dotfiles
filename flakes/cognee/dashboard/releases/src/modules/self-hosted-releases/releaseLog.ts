// What /api/releases answers on a self-hosted Cognee: upstream's release log,
// plus the GitHub notes of the running version and the result of looking for
// a newer stable release.
//
// Upstream's useReleases hook validates the answer with the parser below, so
// this file must not import anything from upstream at run time; the types are
// erased.

import type { Release, ReleaseLog } from "./upstream";

/** A release as GitHub publishes it: the notes are one Markdown document. */
export interface GithubRelease extends Release {
  markdown?: string;
}

export interface DeploymentReleaseLog extends ReleaseLog {
  releases: GithubRelease[];
  /** Present when the log comes from this deployment's own route; absent on Cognee Cloud. */
  upstream?: {
    status: "checked" | "unavailable" | "unsupported";
    update: GithubRelease | null;
  };
}

function stringList(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((v): v is string => typeof v === "string" && v.length > 0) : [];
}

function parseRelease(item: unknown): GithubRelease[] {
  if (typeof item !== "object" || item === null) return [];
  const r = item as Record<string, unknown>;
  if (typeof r.version !== "string" || !r.version) return [];
  return [{
    version: r.version,
    releasedAt: typeof r.releasedAt === "string" ? r.releasedAt : null,
    summary: typeof r.summary === "string" ? r.summary : "",
    highlights: stringList(r.highlights),
    fixes: stringList(r.fixes),
    hasNotes: r.hasNotes === true,
    markdown: typeof r.markdown === "string" ? r.markdown : undefined,
  }];
}

/** Validates the route's answer; throws so the query errors instead of rendering junk. */
export function parseDeploymentReleaseLog(data: unknown): DeploymentReleaseLog {
  if (typeof data !== "object" || data === null || !Array.isArray((data as { releases?: unknown }).releases)) {
    throw new Error("release log: unexpected shape");
  }
  const raw = data as Record<string, unknown>;
  const releases = (raw.releases as unknown[]).flatMap(parseRelease);
  const upstream = raw.upstream as Record<string, unknown> | undefined;
  const status = upstream?.status;
  return {
    runningVersion: typeof raw.runningVersion === "string" ? raw.runningVersion : null,
    available: raw.available === true,
    stale: raw.stale === true,
    releases,
    ...(status === "checked" || status === "unavailable" || status === "unsupported"
      ? { upstream: { status, update: status === "checked" ? parseRelease(upstream?.update)[0] ?? null : null } }
      : {}),
  };
}
