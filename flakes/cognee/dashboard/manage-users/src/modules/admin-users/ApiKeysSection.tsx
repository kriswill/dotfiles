"use client";

import { useCallback, useState } from "react";
import type { ReactElement } from "react";
import { adminApi } from "./api";
import type { ApiKeyInfo, NewApiKey, UserDetail } from "./api";
import { Button, Card, ConfirmDialog, Dialog, DialogActions, DialogError, EmptyRow, TextField, faintText, formatDate, mutedText, notifyDone, rowStyle, useSubmit } from "./ui";
import { TEXT } from "./upstream";

const MONO = "var(--font-mono)";

function IssuedKey({ issued, onClose }: { issued: NewApiKey; onClose: () => void }): ReactElement {
  const [copied, setCopied] = useState<boolean | null>(null);
  const copy = (): void => {
    navigator.clipboard.writeText(issued.key).then(() => setCopied(true), () => setCopied(false));
  };
  return (
    <Dialog title="Copy the new key" hint="This is the only time the key is shown. Cognee keeps a hash of it, not the key." onClose={onClose}>
      <output aria-label="New API key" className="block select-all break-all rounded-md px-3 py-2.5"
        style={{ fontFamily: MONO, fontSize: 12, color: "#22C55E", background: "rgba(34,197,94,0.12)", border: "1px solid rgba(34,197,94,0.4)" }}>
        {issued.key}
      </output>
      <p role="status" style={{ ...mutedText, minHeight: 20 }}>
        {copied === true && "Copied to the clipboard."}
        {copied === false && "Could not copy. Select the key and copy it yourself."}
      </p>
      <DialogActions>
        <Button onClick={copy}>Copy key</Button>
        <Button variant="primary" onClick={onClose}>Done</Button>
      </DialogActions>
    </Dialog>
  );
}

function CreateKeyDialog({ user, onClose, onIssued }: { user: UserDetail; onClose: () => void; onIssued: (key: NewApiKey) => void }): ReactElement {
  const [name, setName] = useState("");
  const create = useCallback(async () => onIssued(await adminApi.createApiKey(user.id, name.trim())), [user.id, name, onIssued]);
  const { busy, error, submit } = useSubmit(create);
  const ready = name.trim().length > 0;
  return (
    <Dialog title="Create an API key" hint={`The key acts as ${user.email}, with everything that account can reach.`} onClose={onClose}>
      <form className="flex flex-col gap-4" onSubmit={(event) => { event.preventDefault(); if (ready && !busy) submit(); }}>
        <TextField label="Key name" value={name} onChange={setName} maxLength={80} autoComplete="off" autoFocus hint="What will use it, for example Hermes on mini." />
        <DialogError message={error} />
        <DialogActions>
          <Button onClick={onClose}>Cancel</Button>
          <Button type="submit" variant="primary" disabled={!ready} busyLabel={busy && "Creating…"}>Create key</Button>
        </DialogActions>
      </form>
    </Dialog>
  );
}

export default function ApiKeysSection({ user, onChanged }: { user: UserDetail; onChanged: () => void }): ReactElement {
  const [creating, setCreating] = useState(false);
  const [issued, setIssued] = useState<NewApiKey | null>(null);
  const [revoking, setRevoking] = useState<ApiKeyInfo | null>(null);
  const full = user.apiKeys.length >= user.maxApiKeys;

  return (
    <Card title="API keys"
      hint={full ? `This account holds the most keys Cognee allows (${user.maxApiKeys}). Revoke one to create another.` : "Keys let agents and scripts act as this account. Only names and dates are kept readable."}
      action={<Button disabled={full} onClick={() => setCreating(true)}>Create key</Button>}>
      {user.apiKeys.length === 0 ? (
        <EmptyRow>No API keys.</EmptyRow>
      ) : (
        <ul aria-label="API keys" className="m-0 list-none p-0">
          {user.apiKeys.map((key) => {
            const name = key.name || "Unnamed key";
            return (
              <li key={key.id} className="flex flex-wrap items-center justify-between gap-x-6 gap-y-2" style={rowStyle}>
                <div className="min-w-0 flex-1 basis-56">
                  <p className="break-words" style={{ fontSize: 14, color: TEXT, margin: 0 }}>
                    {name}
                    {key.label && <span style={{ ...faintText, fontFamily: MONO, marginLeft: 10 }}>{key.label}</span>}
                  </p>
                  <p style={{ ...mutedText, marginTop: 2 }}>
                    Created {formatDate(key.createdAt) ?? "at an unknown date"}. {key.lastUsedAt ? `Last used ${formatDate(key.lastUsedAt, true)}.` : "Never used."}
                  </p>
                </div>
                <Button variant="danger" aria-label={`Revoke ${name}`} onClick={() => setRevoking(key)}>Revoke</Button>
              </li>
            );
          })}
        </ul>
      )}

      {creating && (
        <CreateKeyDialog user={user} onClose={() => setCreating(false)}
          onIssued={(key) => { setCreating(false); setIssued(key); onChanged(); }} />
      )}
      {issued && <IssuedKey issued={issued} onClose={() => setIssued(null)} />}
      {revoking && (
        <ConfirmDialog title="Revoke this API key?" confirmLabel="Revoke key" busyLabel="Revoking…" destructive
          onClose={() => setRevoking(null)}
          onConfirm={async () => {
            await adminApi.revokeApiKey(user.id, revoking.id);
            notifyDone("API key revoked", revoking.name ?? "");
            setRevoking(null);
            onChanged();
          }}>
          <p>Anything using <strong style={{ color: TEXT }}>{revoking.name || "this key"}</strong> stops working at once. This cannot be undone; create a new key to replace it.</p>
        </ConfirmDialog>
      )}
    </Card>
  );
}
