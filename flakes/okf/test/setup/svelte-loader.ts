// bun test loader for Svelte 5. bun-plugin-svelte can't run under the test
// runtime (its virtual `bun-svelte:*.css` imports need build-time onResolve,
// which never fires for runtime plugins) — so compile directly: client side,
// styles injected via JS. See docs/svelt/learnings.md (2026-07-02).
import { readFileSync } from "fs";
import { plugin } from "bun";
import { compile, compileModule } from "svelte/compiler";

const ts = new Bun.Transpiler({ loader: "ts" });

plugin({
  name: "svelte-test-loader",
  setup(b) {
    b.onLoad({ filter: /\.svelte$/ }, async (args) => ({
      contents: compile(await Bun.file(args.path).text(), {
        generate: "client",
        css: "injected",
        dev: true,
        runes: true,
        filename: args.path,
      }).js.code,
      loader: "ts",
    }));
    b.onLoad({ filter: /\.svelte\.[tj]s$/ }, async (args) => {
      let src = await Bun.file(args.path).text();
      if (args.path.endsWith(".ts")) src = await ts.transform(src);
      return {
        contents: compileModule(src, { generate: "client", dev: true, filename: args.path }).js.code,
        loader: "js",
      };
    });
    // bun test resolves package exports with the "default" (server) condition
    // and has no --conditions flag; swap svelte's server entries for their
    // client siblings (same dir, so relative imports resolve identically).
    b.onLoad({ filter: /svelte\/src\/(?:[^/]+\/)*index-server\.js$/ }, (args) => ({
      contents: readFileSync(args.path.replace(/index-server\.js$/, "index-client.js"), "utf8"),
      loader: "js",
    }));
  },
});
