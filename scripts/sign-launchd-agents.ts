#!/usr/bin/env bun
// Interactive fzf-based signer for ~/Library/LaunchAgents executables.
//
// Lists every user LaunchAgent with its current signature status
// (unsigned / ad-hoc / Apple-signed-no-team / Developer ID), identity, and
// signed time; lets you multi-select which to (re-)sign; signs the whole
// batch with one passphrase entry via rcodesign against a .p12 you supply
// (never touches macOS codesign/Keychain ACLs directly — see
// docs/unifi-dream-machine.md and knowledge/decisions/nas-mount-codesigning.md
// for why: root-run activation scripts can't reach the login keychain's
// private key, and committing the key via sops would permanently widen
// exposure of a real Apple Developer ID for a cosmetic Login Items label).
// rcodesign is deliberate, not incidental: unlike plain `codesign`, it never
// touches the Keychain/session ACL at all, which is exactly what will let
// this same approach run non-interactively in CI later (certs stored
// there securely) — plain `codesign` could never do that. It only signs
// Mach-O/bundle/DMG/pkg though, not plain scripts — see
// pkgs/nas-mount/package.nix for why nas-mount is a compiled binary now.
//
// You export the .p12 yourself, via Keychain Access.app, selecting only the
// ONE identity you want (right-click > Export Items...) — NOT via `security
// export -t identities`, which sweeps up every identity in the keychain
// indiscriminately (confirmed 2026-07-09: it bundled an unrelated "Apple
// Development" cert from Xcode alongside "Developer ID Application", and
// rcodesign silently signed with the wrong one instead of erroring — no
// `security export` flag filters by specific item, this is a documented
// CLI limitation, not something scriptable around).
//
// Run this yourself, interactively — never through an automated session.
// The passphrase never leaves this process (temp file only, mode 0700 dir,
// deleted on exit); the .p12 itself is yours to manage/delete afterward.

import { accessSync, constants as fsConstants, existsSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const HOME = process.env.HOME ?? "";
const LAUNCH_AGENTS_DIR = join(HOME, "Library/LaunchAgents");
const TIMESTAMP_URL = "http://timestamp.apple.com/ts01";

type SignStatus = "unsigned" | "adhoc" | "signed-no-team" | "developer-id" | "unresolved";

interface AgentInfo {
  label: string;
  plistPath: string;
  execPath: string | null;
  writable: boolean;
  status: SignStatus;
  authority: string | null;
  teamId: string | null;
  signedTime: string | null;
}

function run(cmd: string[]): { stdout: string; stderr: string; exitCode: number } {
  const proc = Bun.spawnSync({ cmd, stdout: "pipe", stderr: "pipe" });
  return {
    stdout: new TextDecoder().decode(proc.stdout ?? new Uint8Array()),
    stderr: new TextDecoder().decode(proc.stderr ?? new Uint8Array()),
    exitCode: proc.exitCode ?? 1,
  };
}

function isWritable(path: string): boolean {
  try {
    accessSync(path, fsConstants.W_OK);
    return true;
  } catch {
    return false;
  }
}

function inspectSignature(execPath: string): Pick<AgentInfo, "status" | "authority" | "teamId" | "signedTime"> {
  const { stdout, stderr } = run(["codesign", "-dv", "--verbose=4", execPath]);
  const text = stdout + stderr;
  if (/code object is not signed at all/.test(text)) {
    return { status: "unsigned", authority: null, teamId: null, signedTime: null };
  }
  const authority = text.match(/^Authority=(.+)$/m)?.[1] ?? null;
  const teamId = text.match(/^TeamIdentifier=(.+)$/m)?.[1] ?? null;
  const signedTime = text.match(/^Signed Time=(.+)$/m)?.[1] ?? null;
  const status: SignStatus = teamId && teamId !== "not set" ? "developer-id" : authority ? "signed-no-team" : "adhoc";
  return { status, authority, teamId, signedTime };
}

function discoverAgents(): AgentInfo[] {
  const files = readdirSync(LAUNCH_AGENTS_DIR).filter((f) => f.endsWith(".plist"));
  const agents: AgentInfo[] = [];
  for (const f of files) {
    const plistPath = join(LAUNCH_AGENTS_DIR, f);
    const { stdout, exitCode } = run(["plutil", "-convert", "json", "-o", "-", plistPath]);
    let label = f.replace(/\.plist$/, "");
    let execPath: string | null = null;
    if (exitCode === 0) {
      try {
        const obj = JSON.parse(stdout);
        if (typeof obj.Label === "string") label = obj.Label;
        if (typeof obj.Program === "string") execPath = obj.Program;
        else if (Array.isArray(obj.ProgramArguments) && typeof obj.ProgramArguments[0] === "string") {
          execPath = obj.ProgramArguments[0];
        }
      } catch {
        // malformed plist JSON — leave execPath null, surfaced as "unresolved"
      }
    }
    if (!execPath) {
      agents.push({ label, plistPath, execPath: null, writable: false, status: "unresolved", authority: null, teamId: null, signedTime: null });
      continue;
    }
    agents.push({ label, plistPath, execPath, writable: isWritable(execPath), ...inspectSignature(execPath) });
  }
  return agents.sort((a, b) => a.label.localeCompare(b.label));
}

function statusIcon(s: SignStatus): string {
  return { "developer-id": "✅", "signed-no-team": "🍎", adhoc: "🔏", unsigned: "❌", unresolved: "❓" }[s];
}

function formatRow(a: AgentInfo): string {
  const identity = a.teamId && a.teamId !== "not set" ? `${a.authority} (${a.teamId})` : (a.authority ?? "-");
  const note = a.execPath?.startsWith("/nix/store/") && !a.writable ? "nix store, read-only" : a.writable ? "" : a.execPath ? "read-only" : "";
  return [statusIcon(a.status), a.label, identity, a.signedTime ?? "-", a.execPath ?? "?", note].join("\t");
}

function fzfSelect(lines: string[], opts: string[]): string[] {
  const proc = Bun.spawnSync({
    cmd: ["fzf", "--delimiter", "\t", "--with-nth=1,2,3,4,5,6", ...opts],
    stdin: Buffer.from(lines.join("\n") + "\n"),
    stdout: "pipe",
    stderr: "inherit",
  });
  const out = new TextDecoder().decode(proc.stdout ?? new Uint8Array()).trim();
  return out.length ? out.split("\n") : [];
}

function readSecret(prompt: string): string {
  // Prompt via /bin/sh's `read -rs` so the terminal handles echo-suppression
  // natively; only the captured value ever touches this process.
  const proc = Bun.spawnSync({
    cmd: ["/bin/sh", "-c", 'read -rs -p "$1" REPLY >&2; printf %s "$REPLY"', "--", prompt],
    stdin: "inherit",
    stdout: "pipe",
    stderr: "inherit",
  });
  process.stderr.write("\n");
  return new TextDecoder().decode(proc.stdout ?? new Uint8Array());
}

function readLine(prompt: string): string {
  const proc = Bun.spawnSync({
    cmd: ["/bin/sh", "-c", 'read -r -p "$1" REPLY >&2; printf %s "$REPLY"', "--", prompt],
    stdin: "inherit",
    stdout: "pipe",
    stderr: "inherit",
  });
  return new TextDecoder().decode(proc.stdout ?? new Uint8Array()).trim();
}

function main() {
  const agents = discoverAgents();
  if (agents.length === 0) {
    console.log(`No LaunchAgents found in ${LAUNCH_AGENTS_DIR}`);
    return;
  }

  const selected = fzfSelect(agents.map(formatRow), [
    "--multi",
    "--header=TAB/shift-TAB to multi-select, enter to sign, esc to just browse.  ✅ Developer ID  🍎 Apple-signed (no team)  🔏 ad-hoc  ❌ unsigned  ❓ unresolved",
    "--preview=codesign -dv --verbose=4 {5} 2>&1",
    "--preview-window=down:12:wrap",
  ]);
  if (selected.length === 0) {
    console.log("Nothing selected.");
    return;
  }

  const chosen = selected.map((line) => {
    const [, label, , , execPath] = line.split("\t");
    return agents.find((a) => a.label === label && a.execPath === execPath)!;
  });

  const signable = chosen.filter((a) => a.writable && a.execPath);
  const skipped = chosen.filter((a) => !a.writable || !a.execPath);
  if (skipped.length) {
    console.log("Skipping (not writable in place):");
    for (const a of skipped) {
      const reason = a.execPath?.startsWith("/nix/store/") ? "nix store — needs a stable-copy module first (see nas-mount.nix)" : "read-only";
      console.log(`  - ${a.label}: ${reason}`);
    }
  }
  if (signable.length === 0) {
    console.log("Nothing left to sign.");
    return;
  }

  console.log(`Signing ${signable.length} agent(s): ${signable.map((a) => a.label).join(", ")}`);
  console.log("Export the ONE identity you want (e.g. \"Developer ID Application: ...\") from Keychain Access.app first:");
  console.log("  right-click it in the login keychain > Export Items... > save as a .p12");
  console.log("(security export -t identities would bundle every identity in the keychain — not what you want here.)");
  const p12 = readLine("Path to that .p12 file: ");
  if (!existsSync(p12)) {
    console.error(`No file at ${p12}. Aborting.`);
    process.exitCode = 1;
    return;
  }

  const tmp = mkdtempSync(join(tmpdir(), "sign-launchd-"));
  const cleanup = () => rmSync(tmp, { recursive: true, force: true });
  process.on("exit", cleanup);
  process.on("SIGINT", () => {
    cleanup();
    process.exit(130);
  });

  try {
    const password = readSecret("p12 passphrase: ");
    const passFile = join(tmp, "pass");
    writeFileSync(passFile, password, { mode: 0o600 });

    for (const a of signable) {
      const sign = run(["rcodesign", "sign", "--p12-file", p12, "--p12-password-file", passFile, "--timestamp-url", TIMESTAMP_URL, a.execPath!]);
      if (sign.exitCode !== 0) {
        console.error(`✗ ${a.label}: ${sign.stderr.trim() || sign.stdout.trim()}`);
        continue;
      }
      const after = inspectSignature(a.execPath!);
      console.log(`✓ ${a.label}: ${after.authority ?? "signed"}${after.signedTime ? ` (${after.signedTime})` : ""}`);
    }
  } finally {
    cleanup();
  }
  console.log(`Done. That .p12 (${p12}) is yours to delete now if you don't need it anymore.`);
}

main();
