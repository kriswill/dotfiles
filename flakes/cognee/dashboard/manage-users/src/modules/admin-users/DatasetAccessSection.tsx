"use client";

import { useState } from "react";
import type { ReactElement } from "react";
import { adminApi } from "./api";
import type { DatasetAccess, UserDetail } from "./api";
import { Badge, Button, Card, EmptyRow, Picker, Refusal, faintText, mutedText, rowStyle, useAction } from "./ui";
import { ACCESS_LEVELS, BORDER_SOFT, TEXT, TEXT_MUTED, levelFor, permissionsFor } from "./upstream";
import type { AccessLevel } from "./upstream";

const UNNAMED = "Unnamed dataset";
const SUBHEAD = { fontSize: 13, fontWeight: 700, color: TEXT_MUTED, margin: 0, padding: "12px 20px 10px", borderTop: `1px solid ${BORDER_SOFT}`, background: "rgba(255,255,255,0.03)" } as const;

function isLevel(value: string): value is AccessLevel {
  return ACCESS_LEVELS.some((option) => option.value === value);
}

function LevelPicker({ label, value, disabled, onChange }: { label: string; value: AccessLevel | null; disabled?: boolean; onChange: (level: AccessLevel) => void }): ReactElement {
  return (
    <Picker label={label} value={value ?? ""} disabled={disabled} onChange={(event) => { if (isLevel(event.target.value)) onChange(event.target.value); }}>
      {/* A set granted outside the dashboard that matches no level. */}
      {value === null && <option value="" disabled>Custom</option>}
      {ACCESS_LEVELS.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
    </Picker>
  );
}

function describe(grant: DatasetAccess): string {
  const level = levelFor(grant.permissions);
  return ACCESS_LEVELS.find((option) => option.value === level)?.label ?? `Custom: ${grant.permissions.join(", ")}`;
}

/** What the account owns, what it has been given, and the way to give more. */
export default function DatasetAccessSection({ user, onChanged }: { user: UserDetail; onChanged: () => void }): ReactElement {
  const { busy, error, run } = useAction(onChanged);
  const [pick, setPick] = useState("");
  const [level, setLevel] = useState<AccessLevel>("view");

  const direct = user.datasetAccess.filter((grant) => grant.source === "direct");
  const inherited = user.datasetAccess.filter((grant) => grant.source !== "direct");
  const granted = new Set(direct.map((grant) => grant.datasetId));
  const options = user.grantableDatasets.filter((dataset) => !granted.has(dataset.id));
  const chosen = options.find((dataset) => dataset.id === pick);

  const setAccess = (datasetId: string, name: string, next: AccessLevel | null, done = "changed"): void =>
    run(datasetId, () => adminApi.setPermissions(user.id, datasetId, next ? permissionsFor(next) : []),
      `Access to ${name} ${next ? done : "removed"}`);

  return (
    <Card title="Dataset access" hint="Access is granted per dataset. Owners always keep full access to their own datasets.">
      <h3 style={SUBHEAD}>Owned by this user</h3>
      {user.ownedDatasets.length === 0 ? (
        <EmptyRow>Owns no datasets.</EmptyRow>
      ) : (
        <ul aria-label="Owned datasets" className="m-0 list-none p-0">
          {user.ownedDatasets.map((dataset) => (
            <li key={dataset.id} className="break-words" style={{ ...rowStyle, padding: "10px 20px", fontSize: 14, color: TEXT }}>{dataset.name || UNNAMED}</li>
          ))}
        </ul>
      )}

      <h3 style={SUBHEAD}>Shared with this user</h3>
      {direct.length + inherited.length === 0 && <EmptyRow>No one has shared a dataset with this user.</EmptyRow>}
      <ul aria-label="Shared datasets" className="m-0 list-none p-0">
        {direct.map((grant) => {
          const name = grant.name || UNNAMED;
          return (
            <li key={grant.datasetId} className="flex flex-wrap items-center justify-between gap-x-6 gap-y-2" style={rowStyle}>
              <div className="min-w-0 flex-1 basis-48">
                <p className="break-words" style={{ fontSize: 14, color: TEXT, margin: 0 }}>
                  {name}
                  {!grant.effective && <span className="ml-2"><Badge tone="warning" title="Cognee only applies a grant on a dataset in the user's current tenant">Not in effect</Badge></span>}
                </p>
                <p style={{ ...mutedText, marginTop: 2 }}>
                  {grant.ownerEmail ? `Owned by ${grant.ownerEmail}` : "Its owner was deleted"}
                  {levelFor(grant.permissions) === null && `. Holds ${grant.permissions.join(", ")}`}
                </p>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <LevelPicker label={`Access to ${name}`} value={levelFor(grant.permissions)} disabled={busy !== null}
                  onChange={(next) => setAccess(grant.datasetId, name, next)} />
                <Button aria-label={`Remove access to ${name}`} busyLabel={busy === grant.datasetId && "Saving…"} disabled={busy !== null}
                  onClick={() => setAccess(grant.datasetId, name, null)}>Remove</Button>
              </div>
            </li>
          );
        })}
        {inherited.map((grant) => (
          <li key={`${grant.source}-${grant.sourceName}-${grant.datasetId}`} className="flex flex-wrap items-center justify-between gap-x-6 gap-y-1" style={rowStyle}>
            <p className="min-w-0 break-words" style={{ fontSize: 14, color: TEXT, margin: 0 }}>{grant.name || UNNAMED}</p>
            <p style={mutedText}>
              {describe(grant)}, through the {grant.source} {grant.sourceName}
              {!grant.effective && " (not in effect)"}
            </p>
          </li>
        ))}
      </ul>

      <div className="flex flex-wrap items-center gap-2" style={rowStyle}>
        <Picker label="Dataset to share" className="min-w-0 flex-1 basis-56" value={pick} disabled={options.length === 0} onChange={(event) => setPick(event.target.value)}>
          <option value="">{options.length === 0 ? "No other datasets to share" : "Choose a dataset…"}</option>
          {options.map((dataset) => (
            <option key={dataset.id} value={dataset.id}>{dataset.name || UNNAMED}{dataset.ownerEmail ? ` (${dataset.ownerEmail})` : ""}</option>
          ))}
        </Picker>
        <LevelPicker label="Level for the new access" value={level} onChange={setLevel} />
        <Button variant="primary" disabled={!chosen || busy !== null} busyLabel={!!chosen && busy === chosen.id && "Granting…"}
          onClick={() => { if (chosen) { setAccess(chosen.id, chosen.name || UNNAMED, level, "granted"); setPick(""); } }}>Grant access</Button>
      </div>
      <p style={{ ...faintText, padding: "0 20px 14px" }}>
        {ACCESS_LEVELS.map((entry) => `${entry.label}: ${entry.hint.toLowerCase()}.`).join(" ")} Access an agent of this user holds is not listed.
      </p>
      <Refusal message={error} />
    </Card>
  );
}
