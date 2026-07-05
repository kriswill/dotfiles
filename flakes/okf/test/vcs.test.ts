// VCS provider unit tests: pure remote-URL normalization, the filesystem
// ("none") provider against tempdir fixtures, and provider auto-selection.
// The nix check sandbox provides git (matching the runtime wrapper's PATH);
// skipIf(!hasGit) only guards against ad-hoc git-less environments.

import { describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { gitProvider, normalizeRemoteUrl } from "../vcs/git";
import { createProvider } from "../vcs";
import { noneProvider } from "../vcs/none";

const hasGit = spawnSync("git", ["--version"], { encoding: "utf8" }).status === 0;

/** Tempdir with: a.md, sub/b.txt, plus junk that must be invisible. */
function fixture(): string {
  const root = mkdtempSync(join(tmpdir(), "okf-vcs-"));
  writeFileSync(join(root, "a.md"), "# a\n");
  mkdirSync(join(root, "sub"));
  writeFileSync(join(root, "sub", "b.txt"), "b\n");
  mkdirSync(join(root, "node_modules"));
  writeFileSync(join(root, "node_modules", "x.js"), "x\n");
  mkdirSync(join(root, ".git"));
  writeFileSync(join(root, ".git", "config"), "\n");
  mkdirSync(join(root, "dist"));
  writeFileSync(join(root, "dist", "out.js"), "o\n");
  return root;
}

describe("normalizeRemoteUrl", () => {
  test("https passes through, .git and trailing slash stripped", () => {
    expect(normalizeRemoteUrl("https://github.com/o/r")).toBe("https://github.com/o/r");
    expect(normalizeRemoteUrl("https://github.com/o/r.git")).toBe("https://github.com/o/r");
    expect(normalizeRemoteUrl("https://codeberg.org/o/r/")).toBe("https://codeberg.org/o/r");
    expect(normalizeRemoteUrl("http://git.internal/team/repo.git")).toBe("https://git.internal/team/repo");
  });

  test("scp-style ssh remotes normalize to https", () => {
    expect(normalizeRemoteUrl("git@github.com:o/r.git")).toBe("https://github.com/o/r");
    expect(normalizeRemoteUrl("git@gitlab.com:group/sub/repo.git")).toBe("https://gitlab.com/group/sub/repo");
  });

  test("ssh:// remotes normalize to https, port dropped", () => {
    expect(normalizeRemoteUrl("ssh://git@github.com/o/r.git")).toBe("https://github.com/o/r");
    expect(normalizeRemoteUrl("ssh://git@git.example.com:2222/o/r")).toBe("https://git.example.com/o/r");
  });

  test("unrecognized shapes yield null", () => {
    expect(normalizeRemoteUrl("file:///srv/git/repo.git")).toBeNull();
    expect(normalizeRemoteUrl("/srv/git/repo")).toBeNull();
  });
});

describe("noneProvider", () => {
  test("trackedFiles: fs walk, junk names skipped at any depth, ignore globs applied, sorted", () => {
    const p = noneProvider(fixture(), ["dist/**"]);
    expect(p.trackedFiles()).toEqual(["a.md", "sub/b.txt"]);
  });

  test("no ignore globs: dist is content", () => {
    const p = noneProvider(fixture());
    expect(p.trackedFiles()).toEqual(["a.md", "dist/out.js", "sub/b.txt"]);
  });

  test("lastModified: file mtime as ISO; dir = newest tracked file under prefix; missing = null", () => {
    const root = fixture();
    const p = noneProvider(root, ["dist/**"]);
    const t = new Date("2026-01-02T03:04:05Z");
    utimesSync(join(root, "sub", "b.txt"), t, t);
    expect(p.lastModified("sub/b.txt")).toBe("2026-01-02T03:04:05+00:00");
    expect(p.lastModified("sub")).toBe(p.lastModified("sub/b.txt"));
    expect(p.lastModified("sub/")).toBe(p.lastModified("sub/b.txt"));
    expect(p.lastModified("nope.md")).toBeNull();
    expect(Date.parse(p.lastModified("a.md")!)).toBeGreaterThan(0);
  });

  test("no citations, no revisions, no remote", () => {
    const p = noneProvider(fixture());
    expect(p.name).toBe("none");
    expect(p.revisionPattern).toBeNull();
    expect(p.resolveRevisions(["abc1234"])).toEqual({});
    expect(p.remoteUrl()).toBeNull();
  });
});

describe("gitProvider", () => {
  test.skipIf(!hasGit)("lastModified: file introduced BY a merge gets the merge date; cleanly-merged files keep their own commit date", () => {
    const root = mkdtempSync(join(tmpdir(), "okf-gitlog-"));
    const git = (date: string, ...args: string[]) => {
      const r = spawnSync("git", args, {
        cwd: root,
        encoding: "utf8",
        env: {
          ...process.env,
          GIT_AUTHOR_NAME: "t",
          GIT_AUTHOR_EMAIL: "t@t",
          GIT_COMMITTER_NAME: "t",
          GIT_COMMITTER_EMAIL: "t@t",
          GIT_AUTHOR_DATE: date,
          GIT_COMMITTER_DATE: date,
        },
      });
      expect(r.status).toBe(0);
    };
    git("", "init", "-q", "-b", "main");
    writeFileSync(join(root, "base.txt"), "base\n");
    git("2026-01-01T10:00:00+01:00", "add", "base.txt");
    git("2026-01-01T10:00:00+01:00", "commit", "-qm", "base");
    git("", "checkout", "-qb", "feat");
    writeFileSync(join(root, "feat.txt"), "feat\n");
    git("2026-01-02T10:00:00+01:00", "add", "feat.txt");
    git("2026-01-02T10:00:00+01:00", "commit", "-qm", "feat");
    git("", "checkout", "-q", "main");
    writeFileSync(join(root, "main.txt"), "main\n");
    git("2026-01-03T10:00:00+01:00", "add", "main.txt");
    git("2026-01-03T10:00:00+01:00", "commit", "-qm", "main");
    // Evil merge: evil.txt exists in NEITHER parent, only in the merge itself.
    git("", "merge", "-q", "--no-ff", "--no-commit", "feat");
    writeFileSync(join(root, "evil.txt"), "evil\n");
    git("2026-01-04T10:00:00+01:00", "add", "evil.txt");
    git("2026-01-04T10:00:00+01:00", "commit", "-qm", "merge feat");

    const p = gitProvider(root);
    expect(p.lastModified("evil.txt")).toBe("2026-01-04T10:00:00+01:00"); // null before --diff-merges=c
    expect(p.lastModified("feat.txt")).toBe("2026-01-02T10:00:00+01:00"); // NOT rewritten to the merge date
    expect(p.lastModified("base.txt")).toBe("2026-01-01T10:00:00+01:00");
    expect(p.lastModified("main.txt")).toBe("2026-01-03T10:00:00+01:00");
  });
});

describe("createProvider", () => {
  test('"none" is always the filesystem provider', () => {
    expect(createProvider("none", fixture(), []).name).toBe("none");
  });

  test('"auto" falls back to the filesystem provider outside git', () => {
    expect(createProvider("auto", fixture(), []).name).toBe("none");
  });

  test('explicit "git" outside a git repo throws instead of degrading', () => {
    // fixture() has a bare .git DIR (not a valid repo) — rev-parse fails.
    expect(() => createProvider("git", mkdtempSync(join(tmpdir(), "okf-nogit-")), [])).toThrow(/not inside a git repository/);
  });

  test.skipIf(!hasGit)('"auto" picks git at a git toplevel (this repo must never silently mtime-date)', () => {
    const root = mkdtempSync(join(tmpdir(), "okf-git-"));
    expect(spawnSync("git", ["init", "-q"], { cwd: root }).status).toBe(0);
    expect(createProvider("auto", root, []).name).toBe("git");
    // …and a nested dir is NOT a toplevel: auto degrades to none, explicit git throws.
    mkdirSync(join(root, "nested"));
    expect(createProvider("auto", join(root, "nested"), []).name).toBe("none");
    expect(() => createProvider("git", join(root, "nested"), [])).toThrow(/not the git toplevel/);
  });
});
