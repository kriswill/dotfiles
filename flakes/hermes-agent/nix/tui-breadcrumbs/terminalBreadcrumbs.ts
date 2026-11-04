import { randomUUID } from 'node:crypto'
import { mkdirSync, readFileSync, readlinkSync, renameSync, rmSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join } from 'node:path'
import { isatty } from 'node:tty'
import { parse } from 'yaml'

export interface BreadcrumbState { storedSid: string | null; info: { cwd?: string } | null }
export interface BreadcrumbStore { subscribe(listener: (state: BreadcrumbState) => void): () => void }
export interface BreadcrumbOptions { env?: Record<string, string | undefined>; terminalId?: () => string | undefined }

const sanitize = (value: string) => value.trim().replace(/^\/+|\/+$/g, '').replace(/[^A-Za-z0-9._-]/g, '-').slice(0, 120)
const terminalVars = ['ZELLIJ_PANE_ID', 'TMUX_PANE', 'KITTY_WINDOW_ID', 'WEZTERM_PANE', 'TERM_SESSION_ID', 'WT_SESSION']

// This package targets Linux; resolve the actual device, never the shared /dev/tty alias.
export function terminalIdentity(
  env: Record<string, string | undefined> = process.env,
  ttyName: (fd: number) => string | undefined = fd => isatty(fd) ? readlinkSync(`/proc/self/fd/${fd}`) : undefined
): string | undefined {
  for (const fd of [0, 1]) {
    try {
      const name = ttyName(fd)
      if (!name) continue
      if (name.startsWith('/dev/pts/') || /^\/dev\/tty\w+/.test(name)) return `tty-${sanitize(name)}`
    } catch { /* Try the next descriptor or multiplexer identity. */ }
  }
  for (const name of terminalVars) {
    if (env[name]) return `${name.toLowerCase()}-${sanitize(env[name]!)}`
  }
  return undefined
}

/** Observe accepted UI state, not RPC responses that may lose an attachment race. */
export function watchTerminalBreadcrumbs(store: BreadcrumbStore, options: BreadcrumbOptions = {}): () => void {
  const env = options.env ?? process.env
  if (env.HERMES_TUI_GATEWAY_URL?.trim()) return () => {}
  const home = env.HERMES_HOME ?? join(homedir(), '.hermes')
  const identity = (options.terminalId ?? (() => terminalIdentity(env)))()
  if (!identity) return () => {}
  let last = ''
  return store.subscribe(state => {
    if (!state.storedSid) return // A reset must not erase the terminal's continuation hint.
    const cwd = state.info?.cwd || env.HERMES_CWD || ''
    const key = JSON.stringify([state.storedSid, cwd])
    if (key === last) return
    let temporary: string | undefined
    try {
      // config.get full omits session settings; use this launch profile's YAML.
      let config: any
      try { config = parse(readFileSync(join(home, 'config.yaml'), 'utf8')) }
      catch (error) {
        if ((error as NodeJS.ErrnoException).code !== 'ENOENT') return
      }
      if (config?.session?.terminal_continue === false) return
      const directory = join(home, 'terminal-sessions')
      mkdirSync(directory, { recursive: true, mode: 0o700 })
      const path = join(directory, identity)
      temporary = `${path}.${randomUUID()}.tmp`
      writeFileSync(temporary, JSON.stringify({ session_id: state.storedSid, cwd, ts: Date.now() / 1000 }), { mode: 0o600, flag: 'wx' })
      renameSync(temporary, path)
      last = key
    } catch { /* Breadcrumb failures must never break attachment or streaming. */ }
    finally {
      if (temporary) {
        try { rmSync(temporary, { force: true }) } catch { /* Best-effort cleanup. */ }
      }
    }
  })
}
