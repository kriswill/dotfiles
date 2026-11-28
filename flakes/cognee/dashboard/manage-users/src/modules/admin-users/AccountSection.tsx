"use client";

import { useId, useState } from "react";
import type { ReactElement, ReactNode } from "react";
import { adminApi } from "./api";
import type { AccountChange, UserDetail } from "./api";
import { Button, Card, ConfirmDialog, Refusal, faintText, mutedText, notifyDone, rowStyle, useAction } from "./ui";
import { TEXT } from "./upstream";

interface SectionProps {
  user: UserDetail;
  onChanged: () => void;
}

interface Confirmation {
  title: string;
  body: ReactNode;
  confirmLabel: string;
  busyLabel: string;
  destructive: boolean;
  change: AccountChange;
  done: string;
}

function Setting({ name, state, explanation, lock, children }: { name: string; state: string; explanation: string; lock?: string | null; children: ReactNode }): ReactElement {
  const id = useId();
  return (
    <div role="group" aria-labelledby={id} className="flex flex-wrap items-center justify-between gap-x-6 gap-y-3" style={rowStyle}>
      <div className="min-w-0 flex-1 basis-64">
        <p id={id} style={{ fontSize: 14, color: TEXT, margin: 0 }}>
          {name}: <strong style={{ fontWeight: 700 }}>{state}</strong>
        </p>
        <p style={{ ...mutedText, marginTop: 2 }}>{explanation}</p>
        {lock && <p id={`${id}-lock`} style={{ ...faintText, marginTop: 6 }}>{lock}</p>}
      </div>
      {children}
    </div>
  );
}

export default function AccountSection({ user, onChanged }: SectionProps): ReactElement {
  const { busy, error, run } = useAction(onChanged);
  const [confirming, setConfirming] = useState<Confirmation | null>(null);
  const change = (key: string, update: AccountChange, done: string): void =>
    run(key, () => adminApi.changeAccount(user.id, update), done);

  return (
    <Card title="Account">
      <Setting name="Superuser" state={user.isSuperuser ? "Yes" : "No"} lock={user.isSuperuser ? user.locks.demote : null}
        explanation="Superusers can manage every account, key and dataset grant on this instance.">
        {user.isSuperuser ? (
          <Button disabled={!!user.locks.demote} onClick={() => setConfirming({
            title: "Remove superuser access?", confirmLabel: "Remove superuser access", busyLabel: "Removing…", destructive: true,
            change: { isSuperuser: false }, done: "Superuser access removed",
            body: <p>{user.email} will no longer be able to manage users. Their own datasets and keys are not affected.</p>,
          })}>Remove superuser access</Button>
        ) : (
          <Button onClick={() => setConfirming({
            title: "Make this user a superuser?", confirmLabel: "Make superuser", busyLabel: "Saving…", destructive: false,
            change: { isSuperuser: true }, done: "Superuser access granted",
            body: <p>{user.email} will be able to reset passwords, issue keys and delete accounts, including yours.</p>,
          })}>Make superuser</Button>
        )}
      </Setting>

      <Setting name="Status" state={user.isActive ? "Active" : "Inactive"} lock={user.isActive ? user.locks.deactivate : null}
        explanation="An inactive account cannot sign in, and its API keys stop working. Nothing is deleted.">
        {user.isActive ? (
          <Button disabled={!!user.locks.deactivate} onClick={() => setConfirming({
            title: "Deactivate this account?", confirmLabel: "Deactivate", busyLabel: "Deactivating…", destructive: true,
            change: { isActive: false }, done: "Account deactivated",
            body: <p>{user.email} is signed out and their API keys stop working until you reactivate the account. Agents they created keep their own keys.</p>,
          })}>Deactivate</Button>
        ) : (
          <Button busyLabel={busy === "active" && "Reactivating…"} onClick={() => change("active", { isActive: true }, "Account reactivated")}>Reactivate</Button>
        )}
      </Setting>

      <Setting name="Email verified" state={user.isVerified ? "Yes" : "No"}
        explanation="A record only. This instance does not require a verified email to sign in.">
        <Button busyLabel={busy === "verified" && "Saving…"}
          onClick={() => change("verified", { isVerified: !user.isVerified }, user.isVerified ? "Marked as unverified" : "Marked as verified")}>
          {user.isVerified ? "Mark as unverified" : "Mark as verified"}
        </Button>
      </Setting>
      <Refusal message={error} />

      {confirming && (
        <ConfirmDialog title={confirming.title} confirmLabel={confirming.confirmLabel} busyLabel={confirming.busyLabel} destructive={confirming.destructive}
          onClose={() => setConfirming(null)}
          onConfirm={async () => {
            await adminApi.changeAccount(user.id, confirming.change);
            notifyDone(confirming.done, user.email);
            setConfirming(null);
            onChanged();
          }}>
          {confirming.body}
        </ConfirmDialog>
      )}
    </Card>
  );
}
