"use client";

import { useCallback, useState } from "react";
import type { ReactElement } from "react";
import { adminApi } from "./api";
import type { UserDetail } from "./api";
import { MIN_PASSWORD_LENGTH } from "./CreateUserDialog";
import { Button, Card, Checkbox, Dialog, DialogActions, DialogError, TextField, notifyDone, useSubmit } from "./ui";

function SetPasswordDialog({ user, onClose, onChanged }: { user: UserDetail; onClose: () => void; onChanged: () => void }): ReactElement {
  const [password, setPassword] = useState("");
  const [repeat, setRepeat] = useState("");
  const [revokeKeys, setRevokeKeys] = useState(false);
  const keyCount = user.apiKeys.length;

  const save = useCallback(async () => {
    const { revokedApiKeys } = await adminApi.setPassword(user.id, password, revokeKeys);
    notifyDone("Password set", revokedApiKeys > 0 ? `${revokedApiKeys} API ${revokedApiKeys === 1 ? "key" : "keys"} revoked.` : user.email);
    onClose();
    onChanged();
  }, [user, password, revokeKeys, onClose, onChanged]);
  const { busy, error, submit } = useSubmit(save);

  const mismatch = repeat.length > 0 && repeat !== password;
  const ready = password.length >= MIN_PASSWORD_LENGTH && repeat === password;

  return (
    <Dialog title="Set a new password" onClose={onClose}
      hint={user.isSelf
        ? "You will be signed out here and everywhere else, and sign in again with the new password."
        : `${user.email} is signed out everywhere. Cognee sends no email, so give them the new password yourself.`}>
      <form className="flex flex-col gap-4" onSubmit={(event) => { event.preventDefault(); if (ready && !busy) submit(); }}>
        <TextField label="New password" type="password" value={password} onChange={setPassword} autoComplete="new-password" autoFocus
          hint={`At least ${MIN_PASSWORD_LENGTH} characters.`} />
        <TextField label="Repeat new password" type="password" value={repeat} onChange={setRepeat} autoComplete="new-password"
          error={mismatch ? "The passwords do not match." : null} />
        {keyCount > 0 && (
          <Checkbox checked={revokeKeys} onChange={setRevokeKeys}
            label={`Also revoke this user's ${keyCount === 1 ? "API key" : `${keyCount} API keys`}. Otherwise they keep working.`} />
        )}
        <DialogError message={error} />
        <DialogActions>
          <Button onClick={onClose}>Cancel</Button>
          <Button type="submit" variant="primary" disabled={!ready} busyLabel={busy && "Setting password…"}>Set password</Button>
        </DialogActions>
      </form>
    </Dialog>
  );
}

export default function PasswordSection({ user, onChanged }: { user: UserDetail; onChanged: () => void }): ReactElement {
  const [open, setOpen] = useState(false);
  return (
    <Card title="Password"
      hint={user.hasPassword
        ? "Signs in to the dashboard with a password. Setting a new one ends every open session."
        : "No password. This account cannot sign in to the dashboard and works through API keys only."}
      action={<Button onClick={() => setOpen(true)}>{user.hasPassword ? "Set a new password" : "Set a password"}</Button>}>
      {open && <SetPasswordDialog user={user} onClose={() => setOpen(false)} onChanged={onChanged} />}
    </Card>
  );
}
