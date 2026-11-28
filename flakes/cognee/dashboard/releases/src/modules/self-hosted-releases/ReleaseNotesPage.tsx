"use client";

import React from "react";
import { AsciiFrame, FONT, LABEL, T, TrackPageView, UpstreamReleasesPage, formatReleaseDate, useReleases } from "./upstream";
import type { GithubRelease } from "./releaseLog";

const Markdown = React.lazy(() => import("react-markdown"));

const NOTE: React.CSSProperties = { ...FONT, fontSize: 13, color: T.muted, margin: 0 };

function GithubNotes({ release }: { release: GithubRelease }): React.ReactElement {
  const url = `https://github.com/topoteretes/cognee/releases/tag/${encodeURIComponent(release.version)}`;
  return (
    <AsciiFrame label="GitHub release" meta={formatReleaseDate(release.releasedAt)}>
      <a href={url} className="underline" style={{ ...NOTE, alignSelf: "flex-start", color: T.lavender }}>
        View {release.version} on GitHub
      </a>
      {release.hasNotes && release.markdown ? (
        <div className="mt-4 break-words [&_a]:underline [&_blockquote]:pl-4 [&_h2]:mt-5 [&_h2]:text-lg [&_h3]:mt-4 [&_h3]:font-semibold [&_li]:my-1 [&_ol]:list-decimal [&_ol]:pl-5 [&_p]:my-2 [&_pre]:overflow-x-auto [&_ul]:list-disc [&_ul]:pl-5" style={{ fontSize: 14, lineHeight: 1.65, overflowWrap: "anywhere" }}>
          <React.Suspense fallback={<p style={NOTE}>Loading release notes…</p>}>
            <Markdown skipHtml disallowedElements={["img"]} urlTransform={(href) => href.startsWith("https://") ? href : undefined}>
              {release.markdown}
            </Markdown>
          </React.Suspense>
        </div>
      ) : <p style={{ ...NOTE, marginTop: 12 }}>GitHub did not publish notes for this release.</p>}
    </AsciiFrame>
  );
}

/**
 * The /releases page. A self-hosted Cognee shows the GitHub notes of the
 * version it runs and of a newer stable release, when there is one. While the
 * log is loading, and for a log that carries no upstream check, this is
 * upstream's page unchanged.
 */
export default function ReleaseNotesPage(): React.ReactElement {
  const { data, isError } = useReleases();
  const upstream = data?.upstream;
  const update = isError ? null : upstream?.update;

  React.useEffect(() => {
    if (update && window.location.hash === "#available-release") {
      document.getElementById("available-release")?.scrollIntoView?.();
    }
  }, [update]);

  if (!isError && !upstream) return <UpstreamReleasesPage />;

  let body: React.ReactNode;
  if (isError || !data || !upstream) {
    body = <p style={NOTE}>Release notes could not be loaded. Try again in a moment.</p>;
  } else if (!data.available) {
    body = <p style={NOTE}>Release notes are not available in this environment.</p>;
  } else {
    const running = data.runningVersion?.replace(/^v?([\d.]+)$/, "v$1");
    const installed = data.releases[0];
    const status = upstream.status === "checked" ? "No newer stable release is available."
      : upstream.status === "unsupported" ? "This build does not use a stable version tag."
        : "Could not check for a newer release on GitHub.";
    body = (
      <>
        <section>
          <h2 className="mb-2 text-base font-semibold">Running version · {running ?? data.runningVersion}</h2>
          {installed ? <GithubNotes release={installed} /> : <p style={NOTE}>Could not load GitHub notes for the running version.</p>}
        </section>
        <section id="available-release" className="mt-8 scroll-mt-4">
          <h2 className="mb-2 text-base font-semibold" style={update ? { color: T.amber } : undefined}>
            {update ? `Update available · ${update.version}` : "Upstream release"}
          </h2>
          {update ? <GithubNotes release={update} /> : <p style={NOTE}>{status}</p>}
        </section>
      </>
    );
  }

  return (
    <div style={{ ...FONT, maxWidth: 760, margin: "0 auto", padding: "32px 16px 64px", color: T.text }}>
      <TrackPageView page="Release notes" />
      <div style={LABEL}>{upstream ? "Self-hosted Cognee" : "Cloud"}</div>
      <h1 style={{ fontSize: 24, fontWeight: 600, margin: "6px 0 4px" }}>Release notes</h1>
      <p style={{ ...NOTE, marginBottom: 24 }}>
        {upstream ? "Release notes for this deployment and newer stable releases on GitHub." : "The Cognee release log is unavailable."}
      </p>
      {body}
    </div>
  );
}
