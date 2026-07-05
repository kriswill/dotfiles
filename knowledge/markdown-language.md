---
type: Reference
title: Markdown Language
description: 'Markdown — the repo''s documentation language (this knowledge bundle, the docs/ manuals, agent instructions), linted and formatted by rumdl via efm, with MD013 deliberately disabled because prose reflow does more harm than good.'
tags: [markdown, language]
timestamp: '2026-07-04T00:00:00-07:00'
---

[Markdown](https://commonmark.org) is the plain-text markup language that
CommonMark standardized; GitHub's renderer is the flavor that matters here,
since it is where this repo's documentation is read.

## How this repo uses it

**It is the documentation language:** this knowledge bundle (OKF concept
docs with YAML frontmatter), the [docs/ manuals](manuals.md), and the agent
instructions ([`AGENTS.md`](../AGENTS.md)) are all markdown. The
[OKF Profile](okf-profile.md) shapes the house dialect — body headings are
H2-only (a body H1 reads as a second title next to the frontmatter
`title`), and links are file-relative because `/`-rooted links break GitHub
rendering.

**Lint + format is rumdl** (Rust, one tool for both) via efm
([nvim LSP](nvim/lsp.md)); the repo-root
[`rumdl.toml`](../rumdl.toml) doubles as efm's root anchor. Its one
setting is load-bearing: MD013 (line length) is disabled project-wide
because the only auto-fix rumdl offers is reflow, which rewraps prose
across headings — long lines are left alone. The rumdl binary is
provisioned by both [neovim](modules/neovim.md) module twins.

**Rendering:** in the terminal via glow (binary from the darwin baseline
[core](modules/core.md), config stowed at `home/glow/`); in the browser,
[okf](packages/okf.md)'s viz-app renders each concept's markdown inside
the graph viewer.

## Citations

- [CommonMark](https://commonmark.org) — the Markdown specification
- [rumdl](https://github.com/rvben/rumdl) — the Rust markdown
  linter/formatter
