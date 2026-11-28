"use client";

import { useEffect, useState } from "react";
import { getLocalApiUrl } from "./upstream";

/**
 * Whether the signed-in session belongs to a superuser. Only decides whether
 * to show the way in; the admin API checks the role on every request.
 */
export function useSuperuser(): boolean {
  const [isSuperuser, setIsSuperuser] = useState(false);

  useEffect(() => {
    const controller = new AbortController();
    fetch(`${getLocalApiUrl()}/api/v1/users/me`, { credentials: "include", cache: "no-store", signal: controller.signal })
      .then((response) => (response.ok ? response.json() : null))
      .then((account: { is_superuser?: unknown } | null) => {
        if (!controller.signal.aborted) setIsSuperuser(account?.is_superuser === true);
      })
      .catch(() => undefined);
    return () => controller.abort();
  }, []);

  return isSuperuser;
}
