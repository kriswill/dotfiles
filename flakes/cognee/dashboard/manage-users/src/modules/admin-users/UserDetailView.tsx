"use client";

import { useCallback } from "react";
import type { ReactElement } from "react";
import Link from "next/link";
import { adminApi } from "./api";
import AccountSection from "./AccountSection";
import ApiKeysSection from "./ApiKeysSection";
import DatasetAccessSection from "./DatasetAccessSection";
import DeleteSection from "./DeleteSection";
import { MANAGE_USERS_PATH } from "./ManageUsersNav";
import PasswordSection from "./PasswordSection";
import TenantsSection from "./TenantsSection";
import { Badge, FOCUS, LoadState, faintText, formatDate, mutedText } from "./ui";
import { TEXT, TEXT_MUTED, pageTitleStyle } from "./upstream";
import { useResource } from "./useResource";

/**
 * Everything about one account, on its own page: who they are, how they sign
 * in, their keys, what they can reach, and removal last.
 */
export default function UserDetailView({ userId }: { userId: string }): ReactElement {
  const load = useCallback((signal: AbortSignal) => adminApi.getUser(userId, signal), [userId]);
  const { resource, reload, refresh } = useResource(load);
  const user = resource.status === "ready" ? resource.data : null;
  const created = formatDate(user?.createdAt ?? null);

  return (
    <main className="mx-auto w-full min-w-0 max-w-4xl px-4 pb-24 pt-6 sm:px-8 sm:py-8" style={{ color: TEXT }}>
      <Link href={MANAGE_USERS_PATH} className={`-ml-1 mb-3 inline-flex min-h-11 items-center gap-1.5 rounded px-1 text-[13px] hover:underline ${FOCUS}`} style={{ color: TEXT_MUTED }}>
        <svg aria-hidden="true" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><polyline points="15 18 9 12 15 6" /></svg>
        All users
      </Link>

      {!user ? (
        <>
          <h1 style={{ ...pageTitleStyle, marginBottom: 16 }}>User</h1>
          <LoadState status={resource.status === "ready" ? "loading" : resource.status} noun="this user" onRetry={reload} />
        </>
      ) : (
        <>
          <header className="mb-6">
            <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
              <h1 className="break-all" style={pageTitleStyle}>{user.email}</h1>
              {user.isSuperuser && <Badge tone="accent">Superuser</Badge>}
              {!user.isActive && <Badge tone="warning">Inactive</Badge>}
              {user.isSelf && <Badge>You</Badge>}
              {user.isAgent && <Badge>Agent</Badge>}
              {user.isDefault && <Badge>Built-in</Badge>}
            </div>
            <p style={{ ...mutedText, marginTop: 6 }}>
              {created ? `Added ${created}.` : "Standard account."}
              {user.parentEmail && ` Agent created by ${user.parentEmail}.`}
              {user.isDefault && " Cognee uses this account when a request carries no credentials."}
            </p>
            <p className="break-all" style={{ ...faintText, marginTop: 4, fontFamily: "var(--font-mono)" }}>{user.id}</p>
          </header>

          <div className="flex flex-col gap-5">
            <AccountSection user={user} onChanged={refresh} />
            <PasswordSection user={user} onChanged={refresh} />
            <ApiKeysSection user={user} onChanged={refresh} />
            <DatasetAccessSection user={user} onChanged={refresh} />
            <TenantsSection user={user} onChanged={refresh} />
            <DeleteSection user={user} />
          </div>
        </>
      )}
    </main>
  );
}
