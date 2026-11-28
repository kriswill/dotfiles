"use client";

import { useCallback, useState } from "react";
import type { ReactElement } from "react";
import { adminApi } from "./api";
import type { UserSummary } from "./api";
import { Button, Checkbox, Dialog, DialogActions, DialogError, TextField, useSubmit } from "./ui";

export const MIN_PASSWORD_LENGTH = 8;

export default function CreateUserDialog({ onClose, onCreated }: { onClose: () => void; onCreated: (user: UserSummary) => void }): ReactElement {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [keysOnly, setKeysOnly] = useState(false);
  const [isSuperuser, setIsSuperuser] = useState(false);

  const create = useCallback(async () => {
    onCreated(await adminApi.createUser({ email: email.trim(), password: keysOnly ? null : password, isSuperuser: !keysOnly && isSuperuser }));
  }, [email, password, keysOnly, isSuperuser, onCreated]);
  const { busy, error, submit } = useSubmit(create);

  const ready = email.trim().includes("@") && (keysOnly || password.length >= MIN_PASSWORD_LENGTH);

  return (
    <Dialog title="Add user" hint="Cognee sends no email. Give the person their password yourself, or create an API key for an agent on the next screen." onClose={onClose}>
      <form className="flex flex-col gap-4" onSubmit={(event) => { event.preventDefault(); if (ready && !busy) submit(); }}>
        <TextField label="Email" type="email" value={email} onChange={setEmail} autoComplete="off" autoFocus required />
        {!keysOnly && (
          <TextField label="Password" type="password" value={password} onChange={setPassword} autoComplete="new-password"
            hint={`At least ${MIN_PASSWORD_LENGTH} characters.`} required />
        )}
        <div>
          <Checkbox label="No password. This account only uses API keys." checked={keysOnly} onChange={setKeysOnly} />
          <Checkbox label="Superuser. Can manage every account on this instance." checked={!keysOnly && isSuperuser} disabled={keysOnly} onChange={setIsSuperuser} />
        </div>
        <DialogError message={error} />
        <DialogActions>
          <Button onClick={onClose}>Cancel</Button>
          <Button type="submit" variant="primary" disabled={!ready} busyLabel={busy && "Adding…"}>Add user</Button>
        </DialogActions>
      </form>
    </Dialog>
  );
}
