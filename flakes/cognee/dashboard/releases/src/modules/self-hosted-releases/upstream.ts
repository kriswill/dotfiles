// The upstream contract: every import the self-hosted release notes take from
// the Cognee dashboard's own source goes through this file (the route handler
// has upstream.server.ts). A rename or removal upstream breaks the build
// here, in one place.

export { useReleases } from "@/modules/releases/useReleases";
export { formatReleaseDate } from "@/modules/releases/releaseLog";
export type { Release, ReleaseLog } from "@/modules/releases/releaseLog";

export { default as UpstreamReleasesPage } from "@/app/(app)/releases/ReleasesPage";
export { TrackPageView } from "@/modules/analytics";
export { AsciiFrame } from "@/app/(app)/dashboard/partials/redesign/AsciiFrame";
export { FONT, LABEL, T } from "@/app/(app)/dashboard/partials/redesign/mono";
