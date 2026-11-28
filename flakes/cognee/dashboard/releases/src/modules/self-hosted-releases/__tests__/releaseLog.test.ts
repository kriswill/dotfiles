import { parseDeploymentReleaseLog } from "../releaseLog";
import { parseReleaseLog } from "@/modules/releases/releaseLog";

const release = { version: "v1.6.10", releasedAt: "2026-11-20T10:00:00Z", summary: "", highlights: [], fixes: [], hasNotes: true };
const cloudLog = { runningVersion: "1.6.2-b45dc59", available: true, stale: false, releases: [release, { version: "" }, null] };

it("reads a log without an upstream check exactly as upstream's parser does", () => {
  expect(parseDeploymentReleaseLog(cloudLog)).toEqual(parseReleaseLog(cloudLog));
  expect(parseDeploymentReleaseLog(cloudLog)).not.toHaveProperty("upstream");
  expect(() => parseDeploymentReleaseLog({ releases: "none" })).toThrow("release log: unexpected shape");
});

it("keeps the GitHub notes and the newer release of a checked log", () => {
  const log = parseDeploymentReleaseLog({
    ...cloudLog,
    releases: [{ ...release, markdown: "Installed notes" }],
    upstream: { status: "checked", update: { ...release, version: "v1.6.11", markdown: "Upgrade notes" } },
  });
  expect(log.releases).toEqual([{ ...release, markdown: "Installed notes" }]);
  expect(log.upstream).toEqual({ status: "checked", update: { ...release, version: "v1.6.11", markdown: "Upgrade notes" } });
});

it.each([
  [{ status: "checked", update: null }, { status: "checked", update: null }],
  [{ status: "checked", update: { version: 7 } }, { status: "checked", update: null }],
  [{ status: "unavailable", update: release }, { status: "unavailable", update: null }],
  [{ status: "unsupported" }, { status: "unsupported", update: null }],
  [{ status: "anything else", update: release }, undefined],
  ["checked", undefined],
])("offers an update only from a completed check (%j)", (upstream, expected) => {
  expect(parseDeploymentReleaseLog({ ...cloudLog, upstream }).upstream).toEqual(expected);
});
