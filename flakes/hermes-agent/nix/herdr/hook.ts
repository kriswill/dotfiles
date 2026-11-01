// The gateway's shell hook (`hooks:` in config.yaml) for Herdr panes. One
// run per event; the payload arrives as JSON on stdin
// (agent/shell_hooks.py): {hook_event_name, session_id, extra: {...}}.
//
// It runs in the hermes-agent service, which has neither the pane's
// environment nor its terminal, so it finds the pane in two steps:
//   session id -> pty: the CLI's terminal breadcrumbs,
//     $HERMES_HOME/terminal-sessions/tty-dev-pts-N {session_id, cwd, ts};
//   pty -> pane: the marker cli.ts (the `hermes` wrapper) keeps there while
//     it runs, $HERMES_HOME/herdr-panes/dev-pts-N.json.
// A session with no live marker (Desktop, messaging, cron, subagents, a CLI
// outside Herdr) reports nothing.
//
// Herdr app (herdr-core) panes take status only as OSC 7501 written to the
// terminal (herdrdev/herdr-core#42: no API writes it), so the record goes
// straight to the pane's pty, where the core parses it as the pane's output.
// Herdr TUI panes get the session id via `herdr pane report-agent-session`,
// as the plugin `herdr integration install hermes` writes does.

import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { APP, hermesHome, markerDir, osc7501, ttyKey, writeTty, type PaneMarker } from "./common.ts";

interface Payload {
  hook_event_name?: string;
  session_id?: string;
  extra?: Record<string, unknown>;
}

const str = (v: unknown): string => (typeof v === "string" ? v : "");

function alive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (e) {
    return (e as { code?: string }).code === "EPERM";
  }
}

/** The live panes whose pty last ran this session. */
function panesOf(sessionId: string): PaneMarker[] {
  const crumbs = join(hermesHome(), "terminal-sessions");
  const panes: PaneMarker[] = [];
  let names: string[];
  try {
    names = readdirSync(crumbs);
  } catch {
    return panes;
  }
  for (const name of names) {
    const m = /^tty-(.+)$/.exec(name);
    if (!m) continue;
    try {
      if (JSON.parse(readFileSync(join(crumbs, name), "utf8")).session_id !== sessionId) continue;
      const marker = JSON.parse(readFileSync(join(markerDir(), `${m[1]}.json`), "utf8")) as PaneMarker;
      if (ttyKey(marker.tty) === m[1] && alive(marker.pid)) panes.push(marker);
    } catch {
      // no marker: not a Herdr pane, or hermes left it
    }
  }
  return panes;
}

function status(pane: PaneMarker, state: string, fields: Record<string, string> = {}): void {
  if (!pane.hc) return;
  try {
    writeTty(pane.tty, osc7501(state, fields));
  } catch {
    // the pane is gone
  }
}

function reportSession(pane: PaneMarker, sessionId: string, startSource: string): void {
  if (!pane.herdr) return;
  const { pane: paneId, socket, bin } = pane.herdr;
  const env: Record<string, string | undefined> = { ...process.env, HERDR_ENV: "1", HERDR_PANE_ID: paneId };
  // The gateway's own HOME would point herdr at the wrong socket.
  if (socket) env.HERDR_SOCKET_PATH = socket;
  try {
    Bun.spawnSync(
      [
        bin || "herdr", "pane", "report-agent-session", paneId,
        "--source", `herdr:${APP}`, "--agent", APP,
        "--seq", `${Date.now()}000000`,
        "--agent-session-id", sessionId,
        "--session-start-source", startSource,
      ],
      { env, stdout: "ignore", stderr: "ignore", timeout: 1000 },
    );
  } catch {
    // herdr missing or not running
  }
}

function main(): void {
  const payload = JSON.parse(readFileSync(0, "utf8") || "{}") as Payload;
  const event = payload.hook_event_name;
  const extra = payload.extra ?? {};
  // agent_loop_stopped names the session only by its key, the stored session id.
  const sessionId = str(payload.session_id) || str(extra.session_key);
  if (!event || !sessionId) return;

  for (const pane of panesOf(sessionId)) {
    switch (event) {
      case "on_session_start":
        reportSession(pane, sessionId, "startup");
        status(pane, "idle");
        break;
      case "on_session_reset":
        reportSession(pane, sessionId, "new");
        status(pane, "idle");
        break;
      case "pre_llm_call":
        if (str(extra.platform) === "cli") reportSession(pane, sessionId, "resume");
        status(pane, "working");
        break;
      case "post_llm_call":
      case "agent_loop_stopped":
        status(pane, "idle");
        break;
      case "on_human_input_request":
        status(pane, "blocked", { kind: str(extra.kind) === "approval" ? "permission" : "question" });
        break;
      case "on_human_input_resolved":
        status(pane, "working");
        break;
    }
  }
}

try {
  main();
} catch {
  // never fail a turn over pane status
}
