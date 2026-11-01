// Shared by cli.ts (the `hermes` wrapper, in the pane) and hook.ts (the
// gateway's shell hook): where the pane markers live and how a status record
// reaches a Herdr app (herdr-core) pane.

import { closeSync, constants, openSync, writeSync } from "node:fs";
import { join } from "node:path";

/** What cli.ts records about the pane it runs in, for hook.ts to find. */
export interface PaneMarker {
  /** The wrapper's pid: the marker is live only while it runs. */
  pid: number;
  /** The pane's pty, e.g. /dev/pts/3. */
  tty: string;
  /** Herdr app (herdr-core): set when HC_TERMINAL_ID is. */
  hc?: { terminal: string };
  /** Herdr TUI: set when HERDR_ENV=1 and HERDR_PANE_ID are. */
  herdr?: { pane: string; socket?: string; bin?: string };
}

export const APP = "hermes";

export function hermesHome(): string {
  const home = process.env.HERMES_HOME;
  if (!home) throw new Error("HERMES_HOME is not set");
  return home;
}

/** One file per pty: the CLI's terminal breadcrumbs are keyed the same way. */
export function markerDir(): string {
  return join(hermesHome(), "herdr-panes");
}

/** `/dev/pts/3` -> `dev-pts-3`, the sanitising hermes_cli/terminal_breadcrumbs.py applies. */
export function ttyKey(tty: string): string {
  return tty.replace(/^\/+|\/+$/g, "").replace(/[^A-Za-z0-9._-]/g, "-");
}

export function markerPath(tty: string): string {
  return join(markerDir(), `${ttyKey(tty)}.json`);
}

/**
 * An OSC 7501 status record (`state=idle:app=hermes`, `state=clear`, ...).
 * herdr-core parses it from the pane's output; `state=clear` drops the status.
 */
export function osc7501(state: string, fields: Record<string, string> = {}): string {
  const parts = [`state=${state}`];
  if (state !== "clear") parts.push(`app=${APP}`);
  for (const [k, v] of Object.entries(fields)) if (v) parts.push(`${k}=${v}`);
  return `\x1b]7501;${parts.join(":")}\x1b\\`;
}

/** Write to a pty without making it our controlling terminal or blocking on it. */
export function writeTty(tty: string, data: string): void {
  const fd = openSync(tty, constants.O_WRONLY | constants.O_NOCTTY | constants.O_NONBLOCK);
  try {
    writeSync(fd, data);
  } finally {
    closeSync(fd);
  }
}
