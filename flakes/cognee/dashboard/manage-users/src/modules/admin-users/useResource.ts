"use client";

import { useCallback, useEffect, useState } from "react";
import { AdminApiError } from "./api";

export type Unavailable = "loading" | "unauthenticated" | "forbidden" | "missing" | "error";

export type Resource<T> = { status: Unavailable } | { status: "ready"; data: T };

function failure(error: unknown): Unavailable {
  const status = error instanceof AdminApiError ? error.status : 0;
  if (status === 401) return "unauthenticated";
  if (status === 403) return "forbidden";
  return status === 404 ? "missing" : "error";
}

/**
 * Loads one admin resource. `reload()` shows the loading state again;
 * `refresh()` re-reads behind the current content, for use after a change.
 * Anything already shown is dropped as soon as a read is refused.
 */
export function useResource<T>(load: (signal: AbortSignal) => Promise<T>): {
  resource: Resource<T>;
  reload: () => void;
  refresh: () => void;
} {
  const [resource, setResource] = useState<Resource<T>>({ status: "loading" });
  const [revision, setRevision] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    load(controller.signal).then(
      (data) => { if (!controller.signal.aborted) setResource({ status: "ready", data }); },
      (error: unknown) => { if (!controller.signal.aborted) setResource({ status: failure(error) }); },
    );
    return () => controller.abort();
  }, [load, revision]);

  const refresh = useCallback(() => setRevision((current) => current + 1), []);
  const reload = useCallback(() => {
    setResource({ status: "loading" });
    refresh();
  }, [refresh]);

  return { resource, reload, refresh };
}
