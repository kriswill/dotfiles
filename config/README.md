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

| Subdir | App | Live location | Sync CLI | At rest |
|---|---|---|---|---|
| `noctalia/` | Noctalia shell | `~/.local/state/noctalia/settings.toml` | `noctalia-config` | plaintext |
| `helium/` | Helium browser | `~/.config/net.imput.helium/` | `helium-config` | **age-encrypted (`*.age`)** |
| `gh/` | GitHub CLI | `~/.config/gh/config.yml` | `gh-config` | plaintext |

Noctalia and Helium are nebula-only; `gh` is **cross-platform** (its CLI ships
via the `git` module twins on both OSes — on a fresh machine run
`gh-config restore` once to materialize the live file). `hosts.yml` (gh auth)
is deliberately never captured.

## How the snapshots are captured

Each app has a `*-config` CLI (built from `pkgs/<app>-config.nix`, put on
`k`'s PATH by `modules/hosts/nebula/users/k/<app>.nix` — or, for a
cross-platform app like gh, by the feature's module twins). They all expose
the same three verbs:

```sh
<app>-config capture   # live  -> repo snapshot   (run after you change settings)
<app>-config restore   # repo snapshot -> live    (atomic; quit the app first)
<app>-config diff       # show snapshot vs live
```

- **`capture`** copies an **allowlist** of files from the live location into the
  matching path under `config/<app>/`. It does *not* commit — it prints the
  `git diff` command so you can review and commit yourself.

  On nebula, capture is **automatic**: a systemd user `.path` unit per app
  (`<app>-config-capture.path`, defined next to the app's package wiring)
  watches the live files via inotify — `PathChanged=` catches the apps'
  atomic-rename saves — and runs `<app>-config capture` a few seconds later.
  Helium's unit skips while the browser runs (live SQLite could snapshot torn;
  Chromium's exit-time writes re-trigger it). The Macs have a launchd
  `WatchPaths` twin for gh (`modules/darwin/git.nix`). Committing remains
  manual by design — the automation only keeps the working-tree snapshot
  fresh, so drift shows up in `git status` instead of being forgotten.
- **`restore`** writes the snapshot back over the live files via the same atomic
  rename the app uses, re-hardening permissions (e.g. `0600`), after backing up
  the current live file. It **refuses to run while the app is running** (a live
  save would race it) unless `FORCE=1`.
- **`diff`** shows what's changed.

Key safety properties, by design:

- **Encryption at rest (helium only).** `helium-config` armored-age-encrypts every
  snapshot file to `config/helium/<rel>.age` (recipient `age1gduheq5…` ==
  `keyring.age.nebula`), so the **PUBLIC** repo holds only opaque ciphertext — no
  visited domains, no Google account identity (`gaia_*`/`user_name` in `Local State`),
  no cookies/logins. `capture` encrypts with the public key (no unlock needed);
  `restore`/`diff` decrypt by pulling the age identity from 1Password via `op read`
  into memory (never off the unencrypted disk). `noctalia-config` is **not** encrypted
  (its `settings.toml` carries no PII).
- **Allowlist only.** `helium-config` captures only the files in its `files=(…)`
  allowlist (`Preferences`, `Local State`, `Bookmarks`, and — encrypted —
  `Cookies` + `Login Data`); `History`, `Web Data`, IndexedDB, etc. are never copied.
  Add new files to the allowlist in `pkgs/helium-config.sh`.
- **Churn filtering.** The JSON snapshots are `jq`-filtered to drop high-churn /
  footgun keys (window geometry, `exit_type: Crashed`, timestamps, metrics) and
  key-sorted for stable diffs. Real settings are preserved. The filter lists live
  at the top of `pkgs/helium-config.sh` (this also keeps capture's compare-skip
  from re-encrypting on trivial churn).

## How to maintain it

1. **Capture after you change settings.**
   ```sh
   helium-config capture                       # or noctalia-config capture
   git -C ~/src/dotfiles diff -- config/helium # review
   git -C ~/src/dotfiles commit -- config/helium
   ```
2. **Noisy diffs?** A volatile key is leaking through. Add it to the `del(...)`
   filter near the top of the relevant `pkgs/<app>-config.nix`, rebuild
   (`nixos-rebuild switch`), re-`capture`, re-check `diff`.
3. **New file worth tracking** (e.g. a `Bookmarks` file once it exists): add its
   relative path to the `files=(...)` allowlist in `pkgs/helium-config.sh`
   with the right transform (`raw` for verbatim, `prefs`/`localstate` for the
   JSON filters), then `capture`. For helium the new entry is stored encrypted
   automatically (the encryption layer is transform-agnostic). **Caveat:** adding
   live-credential files (`Cookies`, `Login Data`) means a repo-compromise *and*
   key-compromise = credential compromise, and those SQLite files are bound to the
   machine's `os_crypt` key (so they only restore on the same machine) — capture
   them with the app quit for a consistent copy.
4. **Adding a brand-new app** to this folder:
   - write `pkgs/<app>-config.nix` (model it on `pkgs/helium-config.nix`
     or `pkgs/noctalia-config.nix`),
   - register it in `modules/packages.nix` (+ an `overlays/<app>-config.nix`),
   - put it on `k`'s PATH via `modules/hosts/nebula/users/k/<app>.nix`,
   - run `<app>-config capture` to create `config/<app>/…`, then `git add` it.
5. **Restoring** (fresh machine, or undo): **quit the app first**, then
   `<app>-config restore`. A `.bak` of the previous live file is left beside it.

> Note: these are `git+file://` flakes — newly created files are invisible to
> Nix evaluation until `git add`-ed. Stage new `packages/*.nix` /
> `modules/**` files before `nixos-rebuild`.
