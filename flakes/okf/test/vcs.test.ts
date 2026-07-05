// VCS provider unit tests. Today: the pure remote-URL normalization; the
// "none" provider's tempdir fixtures join when it lands.

import { describe, expect, test } from "bun:test";
import { normalizeRemoteUrl } from "../vcs/git";

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
