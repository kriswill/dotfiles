import { getServerBackendUrl } from "@/modules/self-hosted-releases/upstream.server";
import type { DeploymentReleaseLog, GithubRelease } from "@/modules/self-hosted-releases/releaseLog";

export const dynamic = "force-dynamic";

const github = "https://api.github.com/repos/topoteretes/cognee/releases";
const versionPattern = /^(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})$/;
// Exact tags may use Python (rc1, .dev0) or SemVer (-rc.1) suffixes.
const exactTagPattern = /^v?\d+\.\d+\.\d+(?:(?:a|b|rc)\d+)?(?:\.post\d+)?(?:\.dev\d+)?(?:-[\da-zA-Z]+(?:[.-][\da-zA-Z]+)*)?(?:\+[\da-zA-Z]+(?:[.-][\da-zA-Z]+)*)?$/;

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status, headers: { "Cache-Control": "no-store", "Content-Type": "application/json" },
  });
}

function stableVersion(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const version = value.replace(/^v/, "");
  return versionPattern.test(version) ? version : null;
}

function newer(candidate: string, installed: string): boolean {
  const current = installed.split(".").map(Number);
  for (const [index, part] of candidate.split(".").map(Number).entries()) {
    if (part !== current[index]) return part > current[index];
  }
  return false;
}

async function fetchRelease(key: string): Promise<GithubRelease | null> {
  const response = await fetch(`${github}/${key}`, {
    headers: { Accept: "application/vnd.github+json" },
    credentials: "omit", redirect: "error", cache: "no-store", signal: AbortSignal.timeout(4000),
  });
  if (!response.ok) return null;
  const data = await response.json();
  const tag = data?.tag_name;
  if (typeof tag !== "string" || data.draft !== false) return null;
  let version = tag;
  if (key === "latest") {
    const stable = stableVersion(tag);
    if (!stable || data.prerelease !== false) return null;
    version = `v${stable}`;
  } else if (key !== `tags/${tag}`) {
    return null;
  }
  const markdown = typeof data.body === "string" ? data.body.slice(0, 64_000) : "";
  return {
    version, releasedAt: typeof data.published_at === "string" ? data.published_at : null,
    markdown, summary: "", highlights: [], fixes: [], hasNotes: !!markdown.trim(),
  };
}

type Entry = { key: string; expires: number; result: Promise<GithubRelease | null> };
const cache: { latest?: Entry; installed?: Entry } = {};

function getRelease(key: string): Promise<GithubRelease | null> {
  const slot = key === "latest" ? "latest" : "installed";
  const previous = cache[slot];
  if (previous?.key === key && previous.expires > Date.now()) return previous.result;
  const entry: Entry = { key, expires: Infinity, result: fetchRelease(key).catch(() => null) };
  cache[slot] = entry;
  void entry.result.then((release) => {
    entry.expires = Date.now() + (release ? (slot === "latest" ? 15 * 60_000 : 24 * 60 * 60_000) : 60_000);
  });
  return entry.result;
}

export async function GET(): Promise<Response> {
  let runningVersion: string | null = null;
  try {
    const health = await fetch(`${getServerBackendUrl()}/health`, {
      credentials: "omit", redirect: "error", cache: "no-store", signal: AbortSignal.timeout(3000),
    });
    if (health.status === 200 || health.status === 503) {
      const data = await health.json();
      const isHealthResult = health.status === 200
        ? data?.status === "ready" && (data.health === "healthy" || data.health === "degraded")
        : data?.status === "not ready" && data.health === "unhealthy";
      const version = data?.version;
      if (isHealthResult && typeof version === "string" && version.length <= 64 && /^v?\d+\.\d+\.\d+[\w.+-]*$/.test(version)) {
        runningVersion = version;
      }
    }
  } catch {
    // No package or GitHub version can stand in for the live API's answer.
  }
  if (!runningVersion) return json({ error: "Running Cognee version unavailable" }, 503);

  const version = stableVersion(runningVersion);
  const tag = exactTagPattern.test(runningVersion) ? `v${runningVersion.replace(/^v/, "")}` : null;
  const [installed, latest] = await Promise.all([
    tag ? getRelease(`tags/${tag}`) : null,
    version ? getRelease("latest") : null,
  ]);
  const data: DeploymentReleaseLog = {
    runningVersion, available: true, stale: false, releases: installed ? [installed] : [],
    upstream: {
      status: !version ? "unsupported" : latest ? "checked" : "unavailable",
      update: version && latest && newer(latest.version.slice(1), version) ? latest : null,
    },
  };
  return json(data);
}
