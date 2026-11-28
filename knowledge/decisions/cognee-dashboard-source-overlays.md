---
type: Decision
title: Ship Cognee Dashboard Features as Source Overlays
description: 'Cognee dashboard features are ordinary source files copied over the upstream Next.js tree at build time, with upstream edits kept to named substituteInPlace seams, because patches broke on upstream changes and could not be linted, tested or reviewed as code.'
tags: [cognee, dashboard, nix, patches, nextjs]
status: stable
generated: { by: claude-code/fable-5.2, at: 2026-11-27T19:40:00-08:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/cognee/README.md
    title: 'flakes/cognee/README.md, "Dashboard changes" (the overlay layout and its seams)'
  - id: next-routing
    resource: https://nextjs.org/docs/app/getting-started/layouts-and-pages
    title: 'Next.js App Router: pages are defined by files under app/'
  - id: next-transpile
    resource: https://nextjs.org/docs/app/api-reference/config/next-config-js/transpilePackages
    title: 'Next.js transpilePackages (what a local package would need)'
---

**Where:** [Cognee](../packages/cognee.md) (`frontend.nix`,
`dashboard/<feature>/`).

## Context

The dashboard is built from the upstream `cognee-frontend` source with
`buildNpmPackage`. Downstream changes were patch files. Manage Users began as
one: a page, its tests, and edits to five upstream files to carry an
`isSuperuser` flag through the tenant context to the sidebar. Growing it into
full account administration would have made that patch a few thousand lines.
A patch that size fails to apply when upstream touches a neighbouring line,
and its TypeScript is never linted, type-checked or tested outside a full
package build.

## Decision

A feature is a directory, `dashboard/<feature>/`, of real files at the paths
they have in the upstream tree. `frontend.nix` copies every feature over the
unpacked source in `postPatch`. A path upstream already has stops the build.

- **No upstream edit for a page.** Next defines routes by files, so
  `src/app/(app)/manage-users/` is enough.[^next-routing]
- **The feature asks for what it needs.** Its sidebar section calls
  `/api/v1/users/me` itself to learn whether the session is a superuser, so
  nothing is threaded through upstream's tenant provider.
- **One seam.** `CustomAppShellNavbar.tsx` gains an import and
  `<ManageUsersNav />`, as two `substituteInPlace --replace-fail` lines. They
  anchor on one short string each. A patch hunk also depends on the three
  lines either side of it.
- **One file imports upstream.** `src/modules/admin-users/upstream.ts`
  re-exports the API URL helper, the dark panel tokens, the modal shell, the
  access levels and the sidebar item components. That file is the list of
  what a version bump can break.
- **Tests travel with the feature** and run in the package's check phase.

The three older patches (API keys, the document reader, release notes) were
then converted the same way. They changed the inside of upstream components,
which a new page does not, so the conversion settled what a seam may be:

- **Mount.** An import and one element, as Manage Users does. The update
  link is mounted in `HelpMenu.tsx`, the top bar's own child, which returns
  a fragment; the link is a top bar item without an edit to `TopBar.tsx`.
- **Wrap one line.** One line of upstream JSX goes inside a feature's
  component, which renders it unchanged when it has nothing to add. A
  document's name becomes a button that opens the reader; the list it sits
  in is wrapped in a scope that says which dataset the rows belong to.
  Nothing is passed down through upstream's props: the patch threaded a
  `reader` prop through five files.
- **Wrap a component from outside.** The agent setup modal is not edited.
  Its two importers import a wrapper that renders it with the same props and
  a wrapped `buildSteps`. The contract is the modal's props, not its lines.
  The build fails if a third upstream file imports the modal directly.
- **Hand over a call.** Upstream's API-key stubs keep their types and
  signatures; each body becomes one call to the feature. The shared release
  query keeps its hook; its validator is the feature's.
- **Swap a page.** `/releases` renders the feature's page, which renders
  upstream's page for the states it does not change.

A feature never edits an upstream test. Where a patch had added cases to
one, the feature has its own test that renders the upstream component the
seam is in.

One `upstream.ts` per module directory, not per feature. A file that
upstream imports back (a parser, the API calls) must not pull in a list
that re-exports upstream components, or the two import each other. Such
files take only types from `upstream.ts`, or sit in a directory whose
`upstream.ts` lists only what they call. The `/api/releases` route handler
has `upstream.server.ts`, so it does not import client components.

Rejected:

- **A local npm package** (`file:` dependency or workspace). It would add
  the package to upstream's `package.json` and lockfile, so `npmDepsHash`
  changes and the lockfile edit must be redone on every bump. Next would need
  `transpilePackages`,[^next-transpile] Tailwind a source entry for it, and
  jest a path mapping: four more upstream edits where the overlay has one.
  The page files would still have to be copied into `src/app`. The package
  would also import the host app's modules, which is the coupling a package
  is supposed to remove.
- **Keeping the patch and trimming it.** The new files are most of it, and a
  patch cannot be linted or tested as source.
- **Overwriting an upstream file from the overlay.** The stubs and the
  release page could have been replaced whole. A replacement keeps building
  when upstream changes the file it shadows, which is the case that most
  needs a look. A seam anchored on the stub's own body fails instead.
- **An overlay for everything.** The sign-in form (no pre-filled default
  credentials, fields a password manager can fill) and the narrow top bar
  restyle upstream's own markup. A copy of either component would stop
  following upstream silently. They stay patches, one file each.

## Consequences

The overlay is ordinary TypeScript, reviewed as a diff of itself. A version
bump fails in a place that names the cause: an overlay collision, a failed
`--replace-fail`, or a type error in `upstream.ts`.[^subflake-readme]

- Upstream files are edited at 27 anchors in 13 files, each a line of
  `frontend.nix`, plus two one-file patches of three hunks each. Before the
  conversion, four patches edited 18 upstream files in 52 hunks, three of
  them tests.
- An anchor is the exact text of an upstream line. A restyled document-name
  `<span>` upstream fails the build until its anchor is updated; that is a
  one-line fix, and the reader's button should be looked at then anyway.
- The overlay is checked only inside an upstream tree. Editor tooling needs
  an unpacked, patched copy of `cognee-frontend` with the overlay copied in.
- The sidebar makes one more `/users/me` request per page load than the
  patch did.
- The reader keeps which document is open in the row, not in the table. A
  row that leaves the list while its document is open closes the reader.

[^subflake-readme]: `flakes/cognee/README.md`, "Dashboard changes"
[^next-routing]: Next.js, layouts and pages
[^next-transpile]: Next.js, `transpilePackages`
