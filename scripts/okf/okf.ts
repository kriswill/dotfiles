// CLI for the knowledge/ OKF bundle. Usage:
//   bun scripts/okf/okf.ts scaffold [--force]   stub catalog concepts from the repo
//   bun scripts/okf/okf.ts index               regenerate index.md files
//   bun scripts/okf/okf.ts validate [--strict] check spec + profile conformance
//   bun scripts/okf/okf.ts viz                 render knowledge/viz.html graph
// See knowledge/okf-profile.md for the conventions these tools enforce.

const commands: Record<string, string> = {
  scaffold: "./scaffold.ts",
  index: "./index-gen.ts",
  validate: "./validate.ts",
  viz: "./viz.ts",
};

const cmd = process.argv[2];
if (!cmd || !commands[cmd]) {
  console.error(`usage: bun scripts/okf/okf.ts <${Object.keys(commands).join("|")}> [flags]`);
  process.exit(cmd ? 1 : 0);
}
await import(commands[cmd]);
