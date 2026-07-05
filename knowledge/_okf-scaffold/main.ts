// This repo's okf scaffolder — the dotfiles-specific metadata pass, invoked
// by `okf scaffold` via okf.toml `[scaffold] script`. One pass per scaffolded
// type, each in its own file beside this entry:
//   modules.ts   — feature modules (darwin/nixos twins) + flake-parts plumbing
//   hosts.ts     — host registrations + host-specific files
//   packages.ts  — pkgs/, overlay-only entries, sub-flakes
//   nvim.ts      — Neovim plugin specs
// Shared repo access + class vocabulary live in lib.ts.
// Idempotence, --force, and the written/skipped summary are owned by the
// injected ctx.emit (okflight's scaffold-api.ts); these passes use only the
// injected API plus node builtins — no runtime import from the okf checkout.
// Lives in knowledge/_okf-scaffold/ (bundle-adjacent tooling): the `_` prefix
// keeps the directory invisible to okf's walkMd/index-gen, so the bundle
// itself stays pure markdown and OKF-conformant.

import type { ScaffoldContext } from "./okf-scaffold-api";
import { scaffoldHosts } from "./hosts";
import { repoOf } from "./lib";
import { scaffoldModules } from "./modules";
import { scaffoldNvim } from "./nvim";
import { scaffoldPackages } from "./packages";

export default async function scaffold(ctx: ScaffoldContext) {
  const repo = repoOf(ctx);
  // Modules first: the hosts pass filters enable flags against the module
  // names and host-qualifies doc slugs that would collide with them.
  const moduleNames = scaffoldModules(ctx, repo);
  scaffoldHosts(ctx, repo, moduleNames);
  scaffoldPackages(ctx, repo);
  scaffoldNvim(ctx, repo);
}
