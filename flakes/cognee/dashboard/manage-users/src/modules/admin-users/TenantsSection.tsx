"use client";

import { useState } from "react";
import type { ReactElement } from "react";
import { adminApi } from "./api";
import type { Membership, UserDetail } from "./api";
import { Badge, Button, Card, ConfirmDialog, EmptyRow, FOCUS, Picker, Refusal, faintText, mutedText, notifyDone, rowStyle, useAction } from "./ui";
import { TEXT, TEXT_MUTED } from "./upstream";

function TenantRow({ user, tenant, busy, onRun, onRemove }: {
  user: UserDetail;
  tenant: Membership;
  busy: string | null;
  onRun: (key: string, action: () => Promise<unknown>, done: string) => void;
  onRemove: () => void;
}): ReactElement {
  const [role, setRole] = useState("");
  const held = new Set(tenant.roles.map((entry) => entry.id));
  const open = (user.availableTenants.find((entry) => entry.id === tenant.id)?.roles ?? []).filter((entry) => !held.has(entry.id));
  const chosen = open.find((entry) => entry.id === role);

  return (
    <li style={rowStyle}>
      <div className="flex flex-wrap items-center justify-between gap-x-6 gap-y-2">
        <p className="flex min-w-0 flex-wrap items-center gap-2 break-words" style={{ fontSize: 14, color: TEXT, margin: 0 }}>
          {tenant.name}
          {tenant.isOwner && <Badge tone="accent">Owner</Badge>}
          {tenant.isCurrent && <Badge title="The tenant this user is working in">Current</Badge>}
        </p>
        <Button variant="danger" disabled={tenant.isOwner} aria-label={`Remove from ${tenant.name}`} onClick={onRemove}>Remove from tenant</Button>
      </div>
      {tenant.isOwner && <p style={{ ...faintText, marginTop: 4 }}>A tenant&apos;s owner cannot be removed from it.</p>}

      <div className="mt-3 flex flex-wrap items-center gap-2">
        <span style={mutedText}>{tenant.roles.length === 0 ? "No roles." : "Roles:"}</span>
        {tenant.roles.map((entry) => (
          <span key={entry.id} className="inline-flex items-center gap-1 rounded-full pl-3" style={{ background: "rgba(255,255,255,0.08)", fontSize: 13, color: TEXT }}>
            {entry.name}
            <button type="button" aria-label={`Remove role ${entry.name}`} disabled={busy !== null}
              onClick={() => onRun(entry.id, () => adminApi.removeRole(user.id, entry.id), `Removed from ${entry.name}`)}
              className={`inline-flex size-11 cursor-pointer items-center justify-center rounded-full disabled:cursor-not-allowed disabled:opacity-50 ${FOCUS}`} style={{ color: TEXT_MUTED }}>
              <svg aria-hidden="true" width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M2.5 2.5l7 7m0-7l-7 7" /></svg>
            </button>
          </span>
        ))}
        {open.length > 0 && (
          <>
            <Picker label={`Role to add in ${tenant.name}`} value={role} onChange={(event) => setRole(event.target.value)}>
              <option value="">Add a role…</option>
              {open.map((entry) => <option key={entry.id} value={entry.id}>{entry.name}</option>)}
            </Picker>
            <Button disabled={!chosen || busy !== null} busyLabel={!!chosen && busy === chosen.id && "Adding…"}
              onClick={() => { if (chosen) { onRun(chosen.id, () => adminApi.addRole(user.id, chosen.id), `Added to ${chosen.name}`); setRole(""); } }}>Add role</Button>
          </>
        )}
      </div>
    </li>
  );
}

/** Cognee's tenants and the roles inside them. Most small instances have none. */
export default function TenantsSection({ user, onChanged }: { user: UserDetail; onChanged: () => void }): ReactElement {
  const { busy, error, run } = useAction(onChanged);
  const [pick, setPick] = useState("");
  const [removing, setRemoving] = useState<Membership | null>(null);

  const joined = new Set(user.tenants.map((tenant) => tenant.id));
  const open = user.availableTenants.filter((tenant) => !joined.has(tenant.id));
  const chosen = open.find((tenant) => tenant.id === pick);

  if (user.availableTenants.length === 0) {
    return (
      <Card title="Tenants and roles" hint="This instance has no tenants, so there are no roles to assign. Access is granted per dataset, above.">
        {null}
      </Card>
    );
  }

  return (
    <Card title="Tenants and roles" hint="A tenant is a shared workspace. Roles group its members so a dataset can be shared with all of them at once.">
      {user.tenants.length === 0 ? (
        <EmptyRow>Not a member of any tenant.</EmptyRow>
      ) : (
        <ul aria-label="Tenants" className="m-0 list-none p-0">
          {user.tenants.map((tenant) => (
            <TenantRow key={tenant.id} user={user} tenant={tenant} busy={busy} onRun={run} onRemove={() => setRemoving(tenant)} />
          ))}
        </ul>
      )}

      {open.length > 0 && (
        <div className="flex flex-wrap items-center gap-2" style={rowStyle}>
          <Picker label="Tenant to add this user to" className="min-w-0 flex-1 basis-56" value={pick} onChange={(event) => setPick(event.target.value)}>
            <option value="">Choose a tenant…</option>
            {open.map((tenant) => <option key={tenant.id} value={tenant.id}>{tenant.name}</option>)}
          </Picker>
          <Button variant="primary" disabled={!chosen || busy !== null} busyLabel={!!chosen && busy === chosen.id && "Adding…"}
            onClick={() => { if (chosen) { run(chosen.id, () => adminApi.addToTenant(user.id, chosen.id), `Added to ${chosen.name}`); setPick(""); } }}>Add to tenant</Button>
        </div>
      )}
      <Refusal message={error} />

      {removing && (
        <ConfirmDialog title={`Remove from ${removing.name}?`} confirmLabel="Remove from tenant" busyLabel="Removing…" destructive
          onClose={() => setRemoving(null)}
          onConfirm={async () => {
            await adminApi.removeFromTenant(user.id, removing.id);
            notifyDone(`Removed from ${removing.name}`, user.email);
            setRemoving(null);
            onChanged();
          }}>
          <p>{user.email} loses their roles in this tenant and their access to its datasets. Agents they created that work in this tenant lose their API keys. Datasets they own stay in the tenant.</p>
        </ConfirmDialog>
      )}
    </Card>
  );
}
