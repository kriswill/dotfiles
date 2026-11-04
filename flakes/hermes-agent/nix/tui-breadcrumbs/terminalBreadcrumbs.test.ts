import { afterEach, expect, test } from 'bun:test'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { atom } from 'nanostores'

import { terminalIdentity, watchTerminalBreadcrumbs } from './terminalBreadcrumbs.ts'

const homes: string[] = []
afterEach(() => homes.splice(0).forEach(home => rmSync(home, { recursive: true, force: true })))
const fixture = () => {
  const home = mkdtempSync(join(tmpdir(), 'tui-breadcrumb-'))
  homes.push(home)
  writeFileSync(join(home, 'config.yaml'), 'session:\n  terminal_continue: true\n')
  return home
}

test('committed attachments and compaction update the stored session, not the view id', () => {
  const home = fixture()
  const state = atom<any>({ sid: 'view', storedSid: null, info: null })
  const stop = watchTerminalBreadcrumbs(state, {
    env: { HERMES_HOME: home, HERMES_CWD: '/launch' }, terminalId: () => 'tty-dev-pts-42'
  })
  const path = join(home, 'terminal-sessions/tty-dev-pts-42')
  state.set({ sid: 'view', storedSid: 'stored-created', info: { cwd: '/workspace' } })
  expect(JSON.parse(readFileSync(path, 'utf8'))).toMatchObject({ session_id: 'stored-created', cwd: '/workspace' })
  state.set({ sid: 'view', storedSid: 'stored-compacted', info: { cwd: '/workspace' } })
  expect(JSON.parse(readFileSync(path, 'utf8')).session_id).toBe('stored-compacted')
  stop()
})

test('the local YAML continuation gate, including aliases, prevents writes', () => {
  const home = fixture()
  writeFileSync(join(home, 'config.yaml'), 'off: &off false\nsession: {terminal_continue: *off}\n')
  const stop = watchTerminalBreadcrumbs(atom({ storedSid: 'disabled', info: null }), {
    env: { HERMES_HOME: home }, terminalId: () => 'tty-dev-pts-42'
  })
  expect(existsSync(join(home, 'terminal-sessions'))).toBe(false)
  stop()
})

test('explicit remote gateways never replace a local continuation hint', () => {
  const home = fixture()
  const stop = watchTerminalBreadcrumbs(atom({ storedSid: 'remote-id', info: null }), {
    env: { HERMES_HOME: home, HERMES_TUI_GATEWAY_URL: 'wss://example.invalid' }, terminalId: () => 'tty-dev-pts-42'
  })
  expect(existsSync(join(home, 'terminal-sessions'))).toBe(false)
  stop()
})

test('reset retains the last hint; new, resume and activation replace it synchronously', () => {
  const home = fixture()
  const state = atom<any>({ storedSid: 'original', info: null })
  const stop = watchTerminalBreadcrumbs(state, { env: { HERMES_HOME: home, HERMES_CWD: '/launch' }, terminalId: () => 'tty-test' })
  const read = () => JSON.parse(readFileSync(join(home, 'terminal-sessions/tty-test'), 'utf8'))
  state.set({ storedSid: null, info: null })
  expect(read().session_id).toBe('original')
  for (const id of ['new', 'resumed', 'activated']) {
    state.set({ storedSid: id, info: null })
    expect(read()).toMatchObject({ session_id: id, cwd: '/launch' })
  }
  const stamp = read().ts
  expect(Math.abs(stamp - Date.now() / 1000)).toBeLessThan(5)
  state.set({ storedSid: 'activated', info: null, streaming: true })
  expect(read().ts).toBe(stamp)
  stop()
  state.set({ storedSid: 'after-unmount', info: null })
  expect(read().session_id).toBe('activated')
})

test('no terminal identity creates no breadcrumb directory', () => {
  const home = fixture()
  const stop = watchTerminalBreadcrumbs(atom({ storedSid: 'no-tty', info: null }), {
    env: { HERMES_HOME: home }, terminalId: () => undefined
  })
  expect(existsSync(join(home, 'terminal-sessions'))).toBe(false)
  stop()
})

test('profile homes are isolated and snapshots cannot redirect filesystem writes', () => {
  const first = fixture()
  const second = fixture()
  const state = atom<any>({ storedSid: 'local-id', info: { profile_id: second, cwd: '/local' } })
  const stop = watchTerminalBreadcrumbs(state, { env: { HERMES_HOME: first }, terminalId: () => 'tty-test' })
  const path = join(first, 'terminal-sessions/tty-test')
  expect(JSON.parse(readFileSync(path, 'utf8')).session_id).toBe('local-id')
  expect(existsSync(join(second, 'terminal-sessions'))).toBe(false)
  expect(statSync(path).mode & 0o777).toBe(0o600)
  expect(readdirSync(join(first, 'terminal-sessions'))).toEqual(['tty-test'])
  stop()
})

test('failed atomic replacement preserves the existing target and removes its temporary file', () => {
  const home = fixture()
  mkdirSync(join(home, 'terminal-sessions/tty-test'), { recursive: true })
  const stop = watchTerminalBreadcrumbs(atom({ storedSid: 'cannot-replace-directory', info: null }), {
    env: { HERMES_HOME: home }, terminalId: () => 'tty-test'
  })
  expect(statSync(join(home, 'terminal-sessions/tty-test')).isDirectory()).toBe(true)
  expect(readdirSync(join(home, 'terminal-sessions'))).toEqual(['tty-test'])
  stop()
})

test('missing config defaults on but invalid YAML never overwrites an existing hint', () => {
  const home = fixture()
  rmSync(join(home, 'config.yaml'))
  const state = atom({ storedSid: 'before', info: null })
  const stop = watchTerminalBreadcrumbs(state, { env: { HERMES_HOME: home }, terminalId: () => 'tty-test' })
  const path = join(home, 'terminal-sessions/tty-test')
  expect(JSON.parse(readFileSync(path, 'utf8')).session_id).toBe('before')
  writeFileSync(join(home, 'config.yaml'), 'session: [broken')
  state.set({ storedSid: 'after', info: null })
  expect(JSON.parse(readFileSync(path, 'utf8')).session_id).toBe('before')
  stop()
})

test('without tty descriptors, terminal fallbacks match classic CLI ordering and sanitization', () => {
  const noTty = () => undefined
  expect(terminalIdentity({ ZELLIJ_PANE_ID: '/pane/a b/', TMUX_PANE: '%2' }, noTty)).toBe('zellij_pane_id-pane-a-b')
  expect(terminalIdentity({ TMUX_PANE: '%2' }, noTty)).toBe('tmux_pane--2')
  expect(terminalIdentity({ WT_SESSION: 'a'.repeat(140) }, noTty)).toBe(`wt_session-${'a'.repeat(120)}`)
  expect(terminalIdentity({}, noTty)).toBeUndefined()
})
