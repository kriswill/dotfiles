# `config/` — application config **snapshots**

This folder holds version-controlled **snapshots** of config files owned by
applications that rewrite their own settings at runtime. It is deliberately
**separate from both other config mechanisms in this repo**:

- It is **not** under `home/`, so the GNU Stow automation
  (`modules/nixos/dotfiles-stow.nix`) never symlinks these files into `$HOME`.
- It is **not** under `modules/`, so the `import-tree` flake loader never
  evaluates them as Nix.

These files are plain data, tracked by git and nothing else.

## Why this exists (and why not stow)

Stow works by moving a file into the repo and replacing the original with a
symlink. That only works for files the application **reads but never rewrites**.

Several apps save their settings by writing a temporary file and then
`rename()`-ing it over the target (an *atomic rename*). A rename replaces the
path entry — so it **destroys a stow symlink on the first save**, turning the
tracked link back into a real, untracked file and silently breaking tracking.
A directory-symlink workaround is worse: it makes the repo copy *be* the live
file, so routine git operations (`reset --hard`, `checkout`, `clean -xfd`) can
revert, corrupt, or delete the running config, and the app's whole runtime state
dir (caches, secrets) ends up in the repo.

So for these apps we keep the **live file (app-owned) and the repo snapshot
physically separate**, and sync them explicitly with a small per-app CLI. The
repo never points at the live file and the live file never points at the repo.

Currently snapshotted here:

| Subdir | App | Live location | Sync CLI |
|---|---|---|---|
| `noctalia/` | Noctalia shell | `~/.local/state/noctalia/settings.toml` | `noctalia-config` |
| `helium/` | Helium browser | `~/.config/net.imput.helium/` | `helium-config` |

## How the snapshots are captured

Each app has a `*-config` CLI (built from `packages/<app>-config.nix`, put on
`k`'s PATH by `modules/hosts/nebula/users/k/<app>.nix`). They all expose the same
three verbs:

```sh
<app>-config capture   # live  -> repo snapshot   (run after you change settings)
<app>-config restore   # repo snapshot -> live    (atomic; quit the app first)
<app>-config diff       # show snapshot vs live
```

- **`capture`** copies an **allowlist** of files from the live location into the
  matching path under `config/<app>/`. It does *not* commit — it prints the
  `git diff` command so you can review and commit yourself.
- **`restore`** writes the snapshot back over the live files via the same atomic
  rename the app uses, re-hardening permissions (e.g. `0600`), after backing up
  the current live file. It **refuses to run while the app is running** (a live
  save would race it) unless `FORCE=1`.
- **`diff`** shows what's changed.

Key safety properties, by design:

- **Allowlist only.** `helium-config` captures just `Default/Bookmarks`,
  `Default/Preferences`, and `Local State` — never `Login Data`, `Cookies`,
  `History`, `Web Data`, IndexedDB, etc. **Secrets and bulk state never enter the
  repo.** Add new files to the allowlist in `packages/<app>-config.nix`.
- **Churn filtering.** The JSON snapshots are `jq`-filtered to drop high-churn /
  footgun keys (window geometry, `exit_type: Crashed`, timestamps, metrics) and
  key-sorted for stable diffs. Real settings are preserved. The filter lists live
  at the top of `packages/<app>-config.nix`.

## How to maintain it

1. **Capture after you change settings.**
   ```sh
   helium-config capture                       # or noctalia-config capture
   git -C ~/src/dotfiles diff -- config/helium # review
   git -C ~/src/dotfiles commit -- config/helium
   ```
2. **Noisy diffs?** A volatile key is leaking through. Add it to the `del(...)`
   filter near the top of the relevant `packages/<app>-config.nix`, rebuild
   (`nixos-rebuild switch`), re-`capture`, re-check `diff`.
3. **New file worth tracking** (e.g. a `Bookmarks` file once it exists): add its
   relative path to the `files=(...)` allowlist in `packages/<app>-config.nix`
   with the right transform (`raw` for verbatim, `prefs`/`localstate` for the
   JSON filters), then `capture`.
4. **Adding a brand-new app** to this folder:
   - write `packages/<app>-config.nix` (model it on `packages/helium-config.nix`
     or `packages/noctalia-config.nix`),
   - register it in `packages/default.nix`,
   - put it on `k`'s PATH via `modules/hosts/nebula/users/k/<app>.nix`,
   - run `<app>-config capture` to create `config/<app>/…`, then `git add` it.
5. **Restoring** (fresh machine, or undo): **quit the app first**, then
   `<app>-config restore`. A `.bak` of the previous live file is left beside it.

> Note: these are `git+file://` flakes — newly created files are invisible to
> Nix evaluation until `git add`-ed. Stage new `packages/*.nix` /
> `modules/**` files before `nixos-rebuild`.
