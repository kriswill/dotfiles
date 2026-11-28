"use client";

import { useState } from "react";
import type { ReactElement } from "react";
import { useRouter } from "next/navigation";
import { adminApi } from "./api";
import type { UserDetail } from "./api";
import { MANAGE_USERS_PATH } from "./ManageUsersNav";
import { Button, Card, ConfirmDialog, faintText, notifyDone } from "./ui";
import { TEXT } from "./upstream";

function plural(count: number, noun: string): string {
  return `${count} ${noun}${count === 1 ? "" : "s"}`;
}

/** Last on the page, and the only change that asks for the email to be typed. */
export default function DeleteSection({ user }: { user: UserDetail }): ReactElement {
  const router = useRouter();
  const [confirming, setConfirming] = useState(false);
  const owned = user.ownedDatasets.length;

  return (
    <Card title="Delete user"
      hint={owned > 0
        ? `Deleting removes the account for good. The ${plural(owned, "dataset")} it owns ${owned === 1 ? "is" : "are"} kept, but left without an owner.`
        : "Deleting removes the account for good. To keep its history and block access instead, deactivate it."}
      action={<Button variant="danger" disabled={!!user.locks.delete} onClick={() => setConfirming(true)}>Delete user</Button>}>
      {user.locks.delete && <p style={{ ...faintText, padding: "0 20px 16px" }}>{user.locks.delete}</p>}

      {confirming && (
        <ConfirmDialog title="Delete this user?" confirmLabel="Delete user" busyLabel="Deleting…" destructive typeToConfirm={user.email}
          onClose={() => setConfirming(false)}
          onConfirm={async () => {
            await adminApi.deleteUser(user.id);
            notifyDone("User deleted", user.email);
            router.push(MANAGE_USERS_PATH);
          }}>
          <p>This cannot be undone. Deleting <strong style={{ color: TEXT }}>{user.email}</strong> removes:</p>
          <ul className="m-0 list-disc pl-5">
            <li>the account and its sign-in</li>
            <li>its {plural(user.apiKeys.length, "API key")}</li>
            <li>its access to datasets shared with it, and its tenant and role memberships</li>
            <li>every agent it created, with their keys</li>
          </ul>
          <p>
            {owned > 0
              ? `Kept: the ${plural(owned, "dataset")} it owns and everything stored in ${owned === 1 ? "it" : "them"}. People ${owned === 1 ? "it was" : "they were"} shared with keep their access, but nobody owns ${owned === 1 ? "it" : "them"} any more. To keep ${owned === 1 ? "it" : "them"} manageable, first give another account full access from that account's page.`
              : "It owns no datasets, so no stored data is left behind."}
          </p>
        </ConfirmDialog>
      )}
    </Card>
  );
}
