"use client";

import { useCallback, useId, useState } from "react";
import type { ButtonHTMLAttributes, CSSProperties, InputHTMLAttributes, ReactElement, ReactNode, SelectHTMLAttributes } from "react";
import { notifications } from "@mantine/notifications";
import {
  BORDER_SOFT, ModalShell, ROW_BORDER, TEXT, TEXT_FAINT, TEXT_MUTED,
  cardStyle, fieldErrorStyle, inputStyle, modalHintStyle, modalTitleStyle, selectStyle,
} from "./upstream";
import type { Unavailable } from "./useResource";

/** The dashboard's lavender focus ring, on every control the overlay adds. */
export const FOCUS = "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#BC9BFF]";

// Upstream's field styles switch the outline off; these keep the look and
// give the focus ring back, at a 44px touch target.
export const fieldStyle: CSSProperties = { ...inputStyle, height: 44, outline: undefined };
// Upstream removes the native arrow; a select still has to look like one.
const CARET = "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' fill='none'%3E%3Cpath d='M3 4.5 6 7.5 9 4.5' stroke='%23A1A1AA' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E\")";
const pickerStyle: CSSProperties = {
  ...selectStyle, height: 44, outline: undefined, color: TEXT, maxWidth: "100%", paddingRight: 32,
  backgroundImage: CARET, backgroundRepeat: "no-repeat", backgroundPosition: "right 12px center",
};

export const mutedText: CSSProperties = { fontSize: 13, color: TEXT_MUTED, margin: 0 };
export const faintText: CSSProperties = { fontSize: 12, color: TEXT_FAINT, margin: 0 };
export const rowStyle: CSSProperties = { padding: "14px 20px", borderTop: `1px solid ${ROW_BORDER}` };

export function messageOf(error: unknown): string {
  return error instanceof Error && error.message ? error.message : "Something went wrong. Try again.";
}

export function notifyDone(title: string, message = ""): void {
  notifications.show({ title, message, color: "green", autoClose: 4000 });
}

const DAY = new Intl.DateTimeFormat(undefined, { dateStyle: "medium" });
const MOMENT = new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" });

export function formatDate(value: string | null, withTime = false): string | null {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return (withTime ? MOMENT : DAY).format(date);
}

const VARIANTS = {
  primary: "bg-[#6510F4] text-white enabled:hover:bg-[#5A0ED6]",
  quiet: "border border-white/10 bg-white/[0.06] text-[#EDECEA]/80 enabled:hover:bg-white/[0.12]",
  danger: "border border-[#EF4444]/45 bg-transparent text-[#FF8A8A] enabled:hover:bg-[#EF4444]/10",
  destroy: "bg-[#EF4444] text-white enabled:hover:bg-[#DC2626]",
} as const;

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: keyof typeof VARIANTS;
  /** Shown instead of the label, with the button held, while the change is sent. */
  busyLabel?: string | false;
}

export function Button({ variant = "quiet", busyLabel, disabled, className = "", children, ...props }: ButtonProps): ReactElement {
  return (
    <button
      type="button"
      {...props}
      disabled={disabled || !!busyLabel}
      aria-busy={busyLabel ? true : undefined}
      className={`inline-flex min-h-11 shrink-0 cursor-pointer items-center justify-center gap-2 rounded-lg px-4 text-[13px] font-medium leading-4 disabled:cursor-not-allowed disabled:opacity-50 ${FOCUS} ${VARIANTS[variant]} ${className}`}
    >
      {busyLabel || children}
    </button>
  );
}

const TONES = {
  accent: { background: "rgba(188,155,255,0.12)", color: "#BC9BFF" },
  neutral: { background: "rgba(255,255,255,0.08)", color: TEXT_MUTED },
  warning: { background: "rgba(245,158,11,0.14)", color: "#FBBF24" },
} as const;

export function Badge({ tone = "neutral", title, children }: { tone?: keyof typeof TONES; title?: string; children: ReactNode }): ReactElement {
  return (
    <span title={title} className="inline-flex items-center whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-medium" style={TONES[tone]}>
      {children}
    </span>
  );
}

/** One section of the user page: a titled card whose rows share one surface. */
export function Card({ title, hint, action, children }: { title: string; hint?: ReactNode; action?: ReactNode; children: ReactNode }): ReactElement {
  const id = useId();
  return (
    <section aria-labelledby={id} style={cardStyle}>
      <div className="flex flex-wrap items-center justify-between gap-x-4 gap-y-3" style={{ padding: "16px 20px" }}>
        <div className="min-w-0">
          <h2 id={id} style={{ fontSize: 15, fontWeight: 700, color: TEXT, margin: 0 }}>{title}</h2>
          {hint && <p style={{ ...mutedText, marginTop: 4, maxWidth: "68ch" }}>{hint}</p>}
        </div>
        {action}
      </div>
      {children}
    </section>
  );
}

/** Why the last change in a section was refused. Announced when it appears. */
export function Refusal({ message }: { message: string | null }): ReactElement | null {
  if (!message) return null;
  return <p role="alert" style={{ ...fieldErrorStyle, fontSize: 13, margin: 0, padding: "0 20px 14px" }}>{message}</p>;
}

interface TextFieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, "onChange"> {
  label: string;
  onChange: (value: string) => void;
  error?: string | null;
  hint?: string;
}

export function TextField({ label, onChange, error, hint, ...props }: TextFieldProps): ReactElement {
  const id = useId();
  const note = error ?? hint;
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} style={{ fontSize: 13, color: TEXT }}>{label}</label>
      <input
        id={id}
        {...props}
        onChange={(event) => onChange(event.target.value)}
        aria-invalid={error ? true : undefined}
        aria-describedby={note ? `${id}-note` : undefined}
        className={FOCUS}
        style={fieldStyle}
      />
      {note && <p id={`${id}-note`} style={error ? fieldErrorStyle : { ...faintText, margin: "4px 0 0" }}>{note}</p>}
    </div>
  );
}

export function Checkbox({ label, checked, onChange, disabled }: { label: ReactNode; checked: boolean; onChange: (checked: boolean) => void; disabled?: boolean }): ReactElement {
  return (
    <label className="flex min-h-11 cursor-pointer items-center gap-3" style={{ fontSize: 13, color: TEXT }}>
      <input type="checkbox" checked={checked} disabled={disabled} onChange={(event) => onChange(event.target.checked)}
        className={`size-4 shrink-0 accent-[#6510F4] ${FOCUS}`} />
      <span>{label}</span>
    </label>
  );
}

export function Picker({ label, className = "", children, ...props }: SelectHTMLAttributes<HTMLSelectElement> & { label: string }): ReactElement {
  return (
    <select aria-label={label} {...props} className={`${FOCUS} ${className}`} style={pickerStyle}>
      {children}
    </select>
  );
}

export function Dialog({ title, hint, onClose, children }: { title: string; hint?: ReactNode; onClose: () => void; children: ReactNode }): ReactElement {
  return (
    <ModalShell onClose={onClose} label={title} width={460}>
      <div>
        <h2 style={modalTitleStyle}>{title}</h2>
        {hint && <p style={{ ...modalHintStyle, lineHeight: 1.5 }}>{hint}</p>}
      </div>
      {children}
    </ModalShell>
  );
}

export function DialogActions({ children }: { children: ReactNode }): ReactElement {
  return <div className="flex flex-wrap justify-end gap-2">{children}</div>;
}

export function DialogError({ message }: { message: string | null }): ReactElement | null {
  return message ? <p role="alert" style={{ ...fieldErrorStyle, fontSize: 13, margin: 0 }}>{message}</p> : null;
}

/** Runs a dialog's change: holds the button while it is sent, keeps the dialog
 *  open with the server's reason when it is refused. */
export function useSubmit(action: () => Promise<void>): { busy: boolean; error: string | null; submit: () => void } {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const submit = useCallback(() => {
    setBusy(true);
    setError(null);
    action().catch((failure: unknown) => {
      setError(messageOf(failure));
      setBusy(false);
    });
  }, [action]);
  return { busy, error, submit };
}

interface ConfirmDialogProps {
  title: string;
  children: ReactNode;
  confirmLabel: string;
  busyLabel: string;
  destructive?: boolean;
  /** When set, the person types this exact text before the change can be sent. */
  typeToConfirm?: string;
  /** Resolves once the change is made; the caller then closes the dialog. */
  onConfirm: () => Promise<void>;
  onClose: () => void;
}

export function ConfirmDialog({ title, children, confirmLabel, busyLabel, destructive = false, typeToConfirm, onConfirm, onClose }: ConfirmDialogProps): ReactElement {
  const { busy, error, submit } = useSubmit(onConfirm);
  const [typed, setTyped] = useState("");
  const matches = typeToConfirm === undefined || typed.trim().toLowerCase() === typeToConfirm.toLowerCase();
  return (
    <Dialog title={title} onClose={onClose}>
      <div className="flex flex-col gap-3" style={{ fontSize: 13, lineHeight: 1.55, color: TEXT_MUTED }}>{children}</div>
      {typeToConfirm !== undefined && (
        <TextField label={`Type ${typeToConfirm} to confirm`} value={typed} onChange={setTyped} autoComplete="off" spellCheck={false} />
      )}
      <DialogError message={error} />
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant={destructive ? "destroy" : "primary"} disabled={!matches} busyLabel={busy && busyLabel} onClick={submit}>{confirmLabel}</Button>
      </DialogActions>
    </Dialog>
  );
}

/** Runs a change made straight from a row, without a dialog. */
export function useAction(onDone: () => void): { busy: string | null; error: string | null; run: (key: string, action: () => Promise<unknown>, done: string) => void } {
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const run = useCallback((key: string, action: () => Promise<unknown>, done: string) => {
    setBusy(key);
    setError(null);
    action().then(
      () => { notifyDone(done); onDone(); },
      (failure: unknown) => setError(messageOf(failure)),
    ).finally(() => setBusy(null));
  }, [onDone]);
  return { busy, error, run };
}

const NOTICES = {
  loading: null,
  unauthenticated: "Sign in again to manage users.",
  forbidden: "Superuser access required.",
  missing: "This user no longer exists.",
} as const;

/** What a page shows in place of content it could not load. */
export function LoadState({ status, noun, onRetry }: { status: Unavailable; noun: string; onRetry: () => void }): ReactElement {
  if (status === "loading") return <p role="status" style={mutedText}>Loading {noun}…</p>;
  if (status === "error") {
    return (
      <div style={{ ...cardStyle, padding: 20 }}>
        <p role="alert" style={{ fontSize: 14, color: TEXT, margin: "0 0 12px" }}>Could not load {noun}.</p>
        <Button onClick={onRetry}>Try again</Button>
      </div>
    );
  }
  return <p role="alert" style={{ fontSize: 14, color: TEXT, margin: 0 }}>{NOTICES[status]}</p>;
}

export function EmptyRow({ children }: { children: ReactNode }): ReactElement {
  return <p style={{ ...mutedText, padding: "14px 20px", borderTop: `1px solid ${BORDER_SOFT}` }}>{children}</p>;
}
