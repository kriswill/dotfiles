// The `hermes` CLI with Herdr pane reporting. The module installs it as
// `hermes`, with HERMES_HERDR_REAL naming the real (makeWrapper'd) CLI.
//
// In a Herdr pane, an interactive chat:
//   - leaves a marker naming the pane's pty for hook.ts, the gateway's shell
//     hook, which runs in the hermes-agent service and can't see this
//     terminal; the CLI's breadcrumb maps the session to the same pty;
//   - in a Herdr app (herdr-core) pane, reports `idle` at launch, so the
//     Agents list shows Hermes before the first prompt (no gateway hook fires
//     when the CLI creates its session), and `state=clear` at exit
//     (herdr-core otherwise keeps a status until the pane's shell exits).
// Anything else (subcommands, --version, -z, -Q, pipes) runs untouched.

import { mkdirSync, readFileSync, readlinkSync, rmSync, writeFileSync } from "node:fs";
import { markerDir, markerPath, osc7501, writeTty, type PaneMarker } from "./common.ts";

// Flags that end in a non-interactive run.
const ONE_SHOT = new Set([
  "-h", "--help", "--version", "-z", "--oneshot", "-Q", "--quiet",
  "--output-format", "--query-file", "--list-tools", "--list-toolsets",
]);
// Flags whose value is the next argument.
const TAKES_VALUE = new Set([
  "-m", "--model", "--provider", "--reasoning", "-t", "--toolsets", "-r", "--resume",
  "--in", "-s", "--skills", "--usage-file", "--api-key", "--base-url", "--image",
  "--max-turns", "--run-budget", "--source", "-q", "--query",
]);

/** No command or `chat`, and no one-shot or informational flag. */
export function interactive(args: string[]): boolean {
  let prev = "";
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const flag = arg.split("=", 1)[0];
    if (ONE_SHOT.has(flag)) return false;
    if (TAKES_VALUE.has(arg)) {
      i++;
    } else if (!arg.startsWith("-") && arg !== "chat" && prev !== "-c" && prev !== "--continue") {
      return false; // another command (--continue's optional name aside)
    }
    prev = arg;
  }
  return true;
}

/** The pty on stdin: /dev/pts/N on Linux, /dev/ttysNNN on macOS (no /proc there). */
function stdinTty(): string | null {
  try {
    if (process.platform === "darwin") {
      const out = Bun.spawnSync(["/usr/bin/tty"], { stdin: "inherit", stdout: "pipe", stderr: "ignore" });
      const tty = out.exitCode === 0 ? out.stdout.toString().trim() : "";
      return /^\/dev\/ttys\d+$/.test(tty) ? tty : null;
    }
    const tty = readlinkSync("/proc/self/fd/0");
    return tty.startsWith("/dev/pts/") ? tty : null;
  } catch {
    return null;
  }
}

function paneMarker(): PaneMarker | null {
  const env = process.env;
  const hc = env.HC_TERMINAL_ID ? { terminal: env.HC_TERMINAL_ID } : undefined;
  const herdr = env.HERDR_ENV === "1" && env.HERDR_PANE_ID
    ? { pane: env.HERDR_PANE_ID, socket: env.HERDR_SOCKET_PATH, bin: env.HERDR_BIN_PATH }
    : undefined;
  if (!hc && !herdr) return null;
  if (!process.stdin.isTTY || !process.stdout.isTTY) return null;
  const tty = stdinTty();
  if (!tty) return null;
  return { pid: process.pid, tty, hc, herdr };
}

function report(marker: PaneMarker, state: string): void {
  if (!marker.hc) return;
  try {
    writeTty(marker.tty, osc7501(state));
  } catch {
    // the pane is gone
  }
}

function removeMarker(marker: PaneMarker): void {
  try {
    const path = markerPath(marker.tty);
    // Only ours: a later hermes in this pty may have replaced it.
    if ((JSON.parse(readFileSync(path, "utf8")) as PaneMarker).pid === marker.pid) rmSync(path);
  } catch {
    // already gone
  }
}

async function main(): Promise<number> {
  const real = process.env.HERMES_HERDR_REAL;
  if (!real) throw new Error("HERMES_HERDR_REAL is not set");
  delete process.env.HERMES_HERDR_REAL;
  const args = process.argv.slice(2);

  const marker = interactive(args) ? paneMarker() : null;
  if (marker) {
    try {
      mkdirSync(markerDir(), { recursive: true, mode: 0o750 });
      writeFileSync(markerPath(marker.tty), JSON.stringify(marker));
    } catch {
      // no marker: hook.ts stays quiet for this pane, hermes still runs
    }
    report(marker, "idle");
  }

  // Ctrl-C and Ctrl-\ reach the whole foreground group, hermes included, and
  // hermes handles them; this process must outlive it to clean up. Signals
  // aimed at this process alone are passed on.
  const ignore = () => {};
  process.on("SIGINT", ignore);
  process.on("SIGQUIT", ignore);
  const child = Bun.spawn([real, ...args], { stdio: ["inherit", "inherit", "inherit"] });
  const forward = (signal: NodeJS.Signals) => () => child.kill(signal);
  process.on("SIGTERM", forward("SIGTERM"));
  process.on("SIGHUP", forward("SIGHUP"));

  const code = await child.exited;
  if (marker) {
    removeMarker(marker);
    report(marker, "clear");
  }
  if (child.signalCode) {
    // Die the way hermes did, so the shell sees the same signal.
    process.removeAllListeners(child.signalCode);
    process.kill(process.pid, child.signalCode);
  }
  return code;
}

process.exit(await main());
