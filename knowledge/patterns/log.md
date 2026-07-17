# Log

## 2026-07-03

- **Update** — `config/` snapshot capture is now automatic on nebula: one
  systemd user `.path` unit per app (gh, noctalia, helium — defined beside
  each app's package wiring) watches the live files with `PathChanged=`
  (inotify; systemd watches parent dirs, so the watch survives atomic-rename
  inode swaps) and runs `<app>-config capture` after a short sleep-debounce
  (deliberately not `TriggerLimit*`, which fails the path unit outright when
  exceeded). Helium's service skips while the browser runs — live SQLite
  (Cookies/Login Data) could snapshot torn; Chromium's exit-time writes
  re-trigger the capture. gh gets a launchd `WatchPaths` twin on darwin
  (dir-watch: launchd kqueue file-watches are inode-based). Capture never
  writes the live file, so restore→capture can't loop; commits stay manual.
