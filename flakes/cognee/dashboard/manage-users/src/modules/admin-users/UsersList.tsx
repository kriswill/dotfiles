"use client";

import { useCallback, useState } from "react";
import type { ReactElement } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { adminApi } from "./api";
import type { UserSummary } from "./api";
import CreateUserDialog from "./CreateUserDialog";
import { MANAGE_USERS_PATH } from "./ManageUsersNav";
import { Badge, Button, FOCUS, LoadState, Picker, fieldStyle, mutedText, notifyDone } from "./ui";
import { BORDER, TEXT, TEXT_MUTED, cardStyle, pageTitleStyle } from "./upstream";
import { useResource } from "./useResource";

export function userPath(id: string): string {
  return `${MANAGE_USERS_PATH}/${encodeURIComponent(id)}`;
}

const HEAD = "px-4 py-3 text-left font-medium whitespace-nowrap";

function UserRow({ user }: { user: UserSummary }): ReactElement {
  return (
    <tr className="hover:bg-white/[0.04]" style={{ borderTop: `1px solid ${BORDER}` }}>
      <th scope="row" className="min-w-56 px-4 py-2 text-left font-medium">
        <span className="flex flex-wrap items-center gap-x-2 gap-y-1">
          <Link href={userPath(user.id)} className={`inline-flex min-h-11 items-center break-all rounded underline-offset-4 hover:underline ${FOCUS}`} style={{ color: TEXT }}>
            {user.email}
          </Link>
          {user.isSelf && <Badge>You</Badge>}
          {user.isAgent && <Badge>Agent</Badge>}
          {user.isDefault && <Badge title="The account Cognee creates for itself">Built-in</Badge>}
        </span>
      </th>
      <td className="whitespace-nowrap px-4 py-2">{user.isSuperuser ? <Badge tone="accent">Superuser</Badge> : "Standard"}</td>
      <td className="whitespace-nowrap px-4 py-2" style={{ color: user.isActive ? TEXT : TEXT_MUTED }}>
        {user.isActive ? "Active" : "Inactive"}
        {!user.hasPassword && <span style={{ color: TEXT_MUTED }}>, no password</span>}
      </td>
      <td className="px-4 py-2 text-right tabular-nums">{user.apiKeyCount}</td>
      <td className="px-4 py-2 text-right tabular-nums">{user.datasetsOwned}</td>
    </tr>
  );
}

export default function UsersList(): ReactElement {
  const router = useRouter();
  const load = useCallback((signal: AbortSignal) => adminApi.listUsers(signal), []);
  const { resource, reload } = useResource(load);
  const [search, setSearch] = useState("");
  const [role, setRole] = useState("all");
  const [adding, setAdding] = useState(false);

  const users = resource.status === "ready" ? resource.data : [];
  const query = search.trim().toLowerCase();
  const visible = users.filter((user) => (
    user.email.toLowerCase().includes(query) && (role === "all" || user.isSuperuser === (role === "superuser"))
  ));

  return (
    <main className="mx-auto w-full min-w-0 max-w-6xl px-4 pb-24 pt-6 sm:px-8 sm:py-8" style={{ color: TEXT }}>
      <header className="mb-6 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 style={pageTitleStyle}>Manage Users</h1>
          <p style={{ ...mutedText, fontSize: 14, marginTop: 4 }}>Every account on this Cognee instance. Open one to change its access.</p>
        </div>
        {resource.status === "ready" && (
          <div className="flex flex-wrap gap-2">
            <Button onClick={reload}>Refresh users</Button>
            <Button variant="primary" onClick={() => setAdding(true)}>Add user</Button>
          </div>
        )}
      </header>

      {resource.status !== "ready" ? (
        <LoadState status={resource.status} noun="users" onRetry={reload} />
      ) : (
        <section aria-label="Users" className="min-w-0" style={cardStyle}>
          <div className="flex flex-wrap items-center gap-3 p-4">
            <input className={`w-full sm:w-72 ${FOCUS}`} style={{ ...fieldStyle, width: undefined }} aria-label="Search by email" type="search" placeholder="Search by email" value={search} onChange={(event) => setSearch(event.target.value)} />
            <Picker label="Filter by role" value={role} onChange={(event) => setRole(event.target.value)}>
              <option value="all">All roles</option>
              <option value="superuser">Superusers</option>
              <option value="user">Standard users</option>
            </Picker>
            <p role="status" className="tabular-nums" style={{ ...mutedText, marginLeft: "auto" }}>{visible.length} of {users.length} users</p>
          </div>
          {visible.length === 0 ? (
            <p style={{ ...mutedText, padding: 24, borderTop: `1px solid ${BORDER}` }}>{users.length === 0 ? "No users to display." : "No users match your filters."}</p>
          ) : (
            <div className={`overflow-x-auto ${FOCUS}`} role="region" aria-label="Users table" tabIndex={0}>
              <table className="w-full min-w-[42rem] border-collapse text-sm">
                <caption className="sr-only">Users, with role, status, and counts of API keys and owned datasets. Open a user to manage them.</caption>
                <thead style={{ background: "rgba(255,255,255,0.03)", color: TEXT_MUTED, borderTop: `1px solid ${BORDER}` }}>
                  <tr>
                    <th scope="col" className={HEAD}>Email</th>
                    <th scope="col" className={HEAD}>Role</th>
                    <th scope="col" className={HEAD}>Status</th>
                    <th scope="col" className={`${HEAD} !text-right`}>API keys</th>
                    <th scope="col" className={`${HEAD} !text-right`}>Datasets owned</th>
                  </tr>
                </thead>
                <tbody>{visible.map((user) => <UserRow key={user.id} user={user} />)}</tbody>
              </table>
            </div>
          )}
        </section>
      )}

      {adding && (
        <CreateUserDialog
          onClose={() => setAdding(false)}
          onCreated={(user) => {
            notifyDone("User added", user.email);
            router.push(userPath(user.id));
          }}
        />
      )}
    </main>
  );
}
