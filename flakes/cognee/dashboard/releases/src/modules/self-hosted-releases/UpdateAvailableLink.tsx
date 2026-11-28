"use client";

import type { ReactElement } from "react";
import Link from "next/link";
import { useReleases } from "./upstream";

/** The top bar's pointer to a newer stable release; nothing while none is known. */
export default function UpdateAvailableLink(): ReactElement | null {
  const { data: releaseLog, isError } = useReleases();
  const update = !isError && releaseLog?.upstream?.status === "checked" ? releaseLog.upstream.update : null;
  if (!update) return null;
  return (
    <Link href="/releases#available-release" aria-label={`Cognee update available: ${update.version}`}
      className="shrink-0 whitespace-nowrap px-2 py-2 text-xs font-semibold text-amber-300 hover:underline">
      <span aria-hidden="true">↑ {update.version}</span>
      <span className="hidden sm:inline" aria-hidden="true"> available</span>
    </Link>
  );
}
