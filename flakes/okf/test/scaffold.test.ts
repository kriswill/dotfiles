// Scaffold config + template unit tests. The collect tier's end-to-end
// behavior (glob -> emit) is exercised by the repo battery and the scratch
// workspace smoke; here: the pure template engine and the [scaffold]
// section's validation.

import { describe, expect, test } from "bun:test";
import { splitCliSections } from "../config-cli";
import { expandTemplate } from "../scaffold-api";

describe("expandTemplate", () => {
  test("replaces known placeholders, leaves unknown tokens verbatim", () => {
    const env = { name: "auth", Title: "Auth", path: "src/auth.py" };
    expect(expandTemplate("services/{name}.md", env)).toBe("services/auth.md");
    expect(expandTemplate("[`{path}`] — {Title} {nope}", env)).toBe("[`src/auth.py`] — Auth {nope}");
  });
});

describe("splitCliSections: [scaffold]", () => {
  test("defaults: no script, no command, no collect", () => {
    expect(splitCliSections({}).scaffold).toEqual({ script: null, command: null, collect: [] });
  });

  test("script consumed; collect entries normalized with defaults", () => {
    const { scaffold, rest } = splitCliSections({
      scaffold: {
        script: "scripts/okf-scaffold.ts",
        collect: [{ glob: "src/*.py", type: "Service", output: "services/{name}.md", comment: "#" }],
      },
    });
    expect(scaffold.script).toBe("scripts/okf-scaffold.ts");
    expect(scaffold.command).toBeNull();
    expect(scaffold.collect).toEqual([
      {
        glob: "src/*.py",
        type: "Service",
        output: "services/{name}.md",
        comment: "#",
        description: null,
        title: null,
        tags: [],
        body: null,
        frontmatter: {},
      },
    ]);
    expect(rest).toEqual({});
  });

  test("script and command are mutually exclusive", () => {
    expect(() => splitCliSections({ scaffold: { script: "a.ts", command: ["python3", "b.py"] } })).toThrow(
      /script and command are mutually exclusive/,
    );
  });

  test("collect: glob/type/output required; escape paths rejected", () => {
    expect(() => splitCliSections({ scaffold: { collect: [{ type: "T", output: "x.md" }] } })).toThrow(
      /collect\[0\]\.glob: required/,
    );
    expect(() =>
      splitCliSections({ scaffold: { collect: [{ glob: "*", type: "T", output: "../x.md" }] } }),
    ).toThrow(/output: must be a relative path/);
  });

  test("unknown placeholders in templates are config errors", () => {
    expect(() =>
      splitCliSections({
        scaffold: { collect: [{ glob: "*", type: "T", output: "x/{basename}.md" }] },
      }),
    ).toThrow(/unknown placeholder \{basename\}/);
    expect(() =>
      splitCliSections({
        scaffold: {
          collect: [{ glob: "*", type: "T", output: "x/{name}.md", frontmatter: { team: "{owner}" } }],
        },
      }),
    ).toThrow(/frontmatter\.team: unknown placeholder \{owner\}/);
  });

  test("output templates reject placeholders unavailable at path-expansion time", () => {
    // {repo} is derived FROM the output path (circular) and the description
    // pair is computed after it — allowing them silently emitted filenames
    // like "widget-{description}.md" or "widget-.md" before this guard.
    for (const bad of ["{repo}", "{description}", "{description-sentence}"])
      expect(() =>
        splitCliSections({
          scaffold: { collect: [{ glob: "*", type: "T", output: `x/{name}-${bad}.md` }] },
        }),
      ).toThrow(/is not available in output templates/);
    // …while the path-safe set stays legal in output, and the full set stays
    // legal in the late-expanded fields.
    const { scaffold } = splitCliSections({
      scaffold: {
        collect: [
          {
            glob: "*",
            type: "T",
            output: "x/{dir}/{name}-{Title}-{timestamp}.md",
            body: "{description-sentence} at {repo}/{path}",
            title: "{description}",
          },
        ],
      },
    });
    expect(scaffold.collect[0]!.output).toBe("x/{dir}/{name}-{Title}-{timestamp}.md");
  });

  test("unknown keys error with paths", () => {
    expect(() => splitCliSections({ scaffold: { scrpit: "x.ts" } })).toThrow(/scaffold\.scrpit: unknown key/);
    expect(() =>
      splitCliSections({ scaffold: { collect: [{ glob: "*", type: "T", output: "x.md", glbo: "y" }] } }),
    ).toThrow(/collect\[0\]\.glbo: unknown key/);
  });
});
