/*
 * cbm-ctl — control CLI for the launchd-supervised codebase-memory-mcp daemon.
 *
 * Subcommands:
 *   status              launchctl state + port listener + indexed projects
 *   flush  [path]       persist the index artifact for a repo (heavy reindex)
 *   commit [-m msg][path]  flush, then git add/commit .codebase-memory
 *   start | stop | restart  launchctl kickstart / bootout the user agent
 *   logs                tail -F the daemon's stdout/stderr logs
 *
 * flush/commit hold a process-wide advisory lock (mkdir-atomic) so concurrent
 * sessions serialize heavy persist work instead of piling on N reindexes at
 * once. The lock does NOT guard DB integrity (the daemon's SQLite is WAL +
 * busy_timeout) and is never held across the daemon's own watcher writes.
 *
 * Tool paths are baked at build time via -D macros (no PATH reliance):
 *   CBM_BIN, GIT, LAUNCHCTL, LSOF, TAIL
 */
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#ifndef CBM_BIN
#define CBM_BIN "codebase-memory-mcp"
#endif
#ifndef GIT
#define GIT "git"
#endif
#ifndef LAUNCHCTL
#define LAUNCHCTL "/bin/launchctl"
#endif
#ifndef LSOF
#define LSOF "/usr/sbin/lsof"
#endif
#ifndef TAIL
#define TAIL "/usr/bin/tail"
#endif

/* nix-darwin registers `launchd.user.agents.<name>` under the label
 * org.nixos.<name> (e.g. the repo's org.nixos.claude-config-dir). This must
 * match the agent name in darwin/module.nix and its StandardOut/ErrorPath. */
#define LABEL "org.nixos.codebase-memory-mcp"
#define PORT_DEFAULT "9749"
#define LOCK_TTL_SECS (30 * 60)
#define LOCK_WAIT_SECS 120
#define DEFAULT_COMMIT_MSG "codebase-memory: refresh in-repo index artifact"

static const char *prog = "cbm-ctl";

/* ── subprocess helpers (no shell) ──────────────────────────────────── */

/* Run argv to completion, inheriting stdio. Returns the exit status, or -1. */
static int run(char *const argv[]) {
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        return -1;
    }
    if (pid == 0) {
        execvp(argv[0], argv);
        fprintf(stderr, "%s: exec %s: %s\n", prog, argv[0], strerror(errno));
        _exit(127);
    }
    int status = 0;
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {
        /* retry */
    }
    return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

/* Run argv and capture stdout (trimmed of trailing newlines) into out.
 * stderr is silenced. Returns 0 only if the child exited 0. */
static int capture(char *const argv[], char *out, size_t n) {
    int fds[2];
    if (pipe(fds) != 0) {
        return -1;
    }
    pid_t pid = fork();
    if (pid < 0) {
        (void)close(fds[0]);
        (void)close(fds[1]);
        return -1;
    }
    if (pid == 0) {
        (void)close(fds[0]);
        (void)dup2(fds[1], STDOUT_FILENO);
        (void)close(fds[1]);
        int devnull = open("/dev/null", O_WRONLY);
        if (devnull >= 0) {
            (void)dup2(devnull, STDERR_FILENO);
            (void)close(devnull);
        }
        execvp(argv[0], argv);
        _exit(127);
    }
    (void)close(fds[1]);
    size_t total = 0;
    ssize_t r;
    while (total + 1 < n && (r = read(fds[0], out + total, n - 1 - total)) > 0) {
        total += (size_t)r;
    }
    out[total] = '\0';
    (void)close(fds[0]);
    int status = 0;
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {
        /* retry */
    }
    while (total > 0 && (out[total - 1] == '\n' || out[total - 1] == '\r')) {
        out[--total] = '\0';
    }
    return (WIFEXITED(status) && WEXITSTATUS(status) == 0) ? 0 : -1;
}

/* ── advisory lock (mkdir-atomic) ───────────────────────────────────── */

static char g_lockdir[4096];
static char g_owner[4160];
static bool g_lock_held = false;

static void lock_release(void) {
    if (!g_lock_held) {
        return;
    }
    (void)unlink(g_owner);
    (void)rmdir(g_lockdir);
    g_lock_held = false;
}

static void on_signal(int sig) {
    lock_release();
    _exit(128 + sig);
}

static bool pid_alive(long pid) {
    if (pid <= 0) {
        return false;
    }
    if (kill((pid_t)pid, 0) == 0) {
        return true;
    }
    return errno == EPERM;
}

static long owner_pid(void) {
    FILE *f = fopen(g_owner, "r");
    if (!f) {
        return -1;
    }
    long pid = -1;
    if (fscanf(f, "%ld", &pid) != 1) {
        pid = -1;
    }
    (void)fclose(f);
    return pid;
}

/* mkdir -p for the cache dir that holds the lock. */
static int ensure_cache_dir(void) {
    const char *home = getenv("HOME");
    if (!home || !*home) {
        return -1;
    }
    char dir[4096];
    snprintf(dir, sizeof dir, "%s/.cache", home);
    (void)mkdir(dir, 0700);
    snprintf(dir, sizeof dir, "%s/.cache/codebase-memory-mcp", home);
    (void)mkdir(dir, 0700);
    return 0;
}

static int lock_acquire(const char *op) {
    const char *home = getenv("HOME");
    if (!home || !*home || ensure_cache_dir() != 0) {
        fprintf(stderr, "%s: cannot resolve $HOME for lock\n", prog);
        return -1;
    }
    snprintf(g_lockdir, sizeof g_lockdir, "%s/.cache/codebase-memory-mcp/cbm-ctl.lock", home);
    snprintf(g_owner, sizeof g_owner, "%s/owner", g_lockdir);

    time_t deadline = time(NULL) + LOCK_WAIT_SECS;
    for (;;) {
        if (mkdir(g_lockdir, 0700) == 0) {
            FILE *f = fopen(g_owner, "w");
            if (f) {
                fprintf(f, "%ld %ld %s\n", (long)getpid(), (long)time(NULL), op);
                (void)fclose(f);
            }
            g_lock_held = true;
            (void)atexit(lock_release);
            (void)signal(SIGINT, on_signal);
            (void)signal(SIGTERM, on_signal);
            (void)signal(SIGHUP, on_signal);
            return 0;
        }
        if (errno != EEXIST) {
            fprintf(stderr, "%s: lock mkdir %s: %s\n", prog, g_lockdir, strerror(errno));
            return -1;
        }
        /* Reclaim a stale lock: dead holder, or older than the TTL backstop. */
        long held_by = owner_pid();
        struct stat st;
        bool stale = (held_by > 0 && !pid_alive(held_by));
        if (stat(g_lockdir, &st) == 0 && (time(NULL) - st.st_mtime) > LOCK_TTL_SECS) {
            stale = true;
        }
        if (stale) {
            (void)unlink(g_owner);
            (void)rmdir(g_lockdir);
            continue;
        }
        if (time(NULL) >= deadline) {
            fprintf(stderr, "%s: lock held by pid %ld; timed out after %ds\n", prog, held_by,
                    LOCK_WAIT_SECS);
            return -1;
        }
        (void)usleep(500000);
    }
}

/* ── repo / json helpers ────────────────────────────────────────────── */

static int resolve_root(const char *arg, char *root, size_t n) {
    if (arg && *arg) {
        snprintf(root, n, "%s", arg);
        return 0;
    }
    char *argv[] = {(char *)GIT, "rev-parse", "--show-toplevel", NULL};
    if (capture(argv, root, n) == 0 && *root) {
        return 0;
    }
    if (getcwd(root, n)) {
        return 0;
    }
    return -1;
}

static void json_escape(const char *s, char *out, size_t n) {
    size_t j = 0;
    for (size_t i = 0; s[i] && j + 2 < n; i++) {
        if (s[i] == '"' || s[i] == '\\') {
            out[j++] = '\\';
        }
        out[j++] = s[i];
    }
    out[j] = '\0';
}

static int do_flush(const char *root) {
    char esc[4096];
    json_escape(root, esc, sizeof esc);
    char json[4200];
    snprintf(json, sizeof json, "{\"repo_path\":\"%s\",\"persistence\":true}", esc);
    fprintf(stderr, "%s: flushing index for %s ...\n", prog, root);
    char *argv[] = {(char *)CBM_BIN, "cli", "index_repository", json, NULL};
    return run(argv);
}

/* ── subcommands ────────────────────────────────────────────────────── */

static int cmd_flush(int argc, char **argv) {
    char root[4096];
    if (resolve_root(argc > 0 ? argv[0] : NULL, root, sizeof root) != 0) {
        fprintf(stderr, "%s: cannot resolve repo root\n", prog);
        return 1;
    }
    if (lock_acquire("flush") != 0) {
        return 1;
    }
    int rc = do_flush(root);
    lock_release();
    return rc == 0 ? 0 : 1;
}

static int cmd_commit(int argc, char **argv) {
    const char *msg = NULL;
    const char *patharg = NULL;
    for (int i = 0; i < argc; i++) {
        if (strcmp(argv[i], "-m") == 0 && i + 1 < argc) {
            msg = argv[++i];
        } else {
            patharg = argv[i];
        }
    }
    if (!msg) {
        msg = DEFAULT_COMMIT_MSG;
    }
    char root[4096];
    if (resolve_root(patharg, root, sizeof root) != 0) {
        fprintf(stderr, "%s: cannot resolve repo root\n", prog);
        return 1;
    }
    if (lock_acquire("commit") != 0) {
        return 1;
    }
    int rc = do_flush(root);
    if (rc == 0) {
        /* Activate the `merge=ours` driver the .gitattributes relies on. */
        char *cfg[] = {(char *)GIT, "-C", root, "config", "merge.ours.driver", "true", NULL};
        (void)run(cfg);
        char *add[] = {(char *)GIT, "-C", root, "add", ".codebase-memory", NULL};
        rc = run(add);
        if (rc == 0) {
            char *ci[] = {(char *)GIT, "-C", root, "commit", "-m", (char *)msg, NULL};
            rc = run(ci);
        }
    }
    lock_release();
    return rc == 0 ? 0 : 1;
}

static int cmd_status(void) {
    const char *port = getenv("CBM_PORT");
    if (!port || !*port) {
        port = PORT_DEFAULT;
    }
    printf("== launchd agent (%s) ==\n", LABEL);
    (void)fflush(stdout);
    char *ll[] = {(char *)LAUNCHCTL, "list", (char *)LABEL, NULL};
    (void)run(ll);

    printf("\n== listener on port %s ==\n", port);
    (void)fflush(stdout);
    char iarg[64];
    snprintf(iarg, sizeof iarg, "-iTCP:%s", port);
    char *ls[] = {(char *)LSOF, "-nP", iarg, "-sTCP:LISTEN", NULL};
    if (run(ls) != 0) {
        printf("(no listener)\n");
    }

    printf("\n== indexed projects ==\n");
    (void)fflush(stdout);
    char *lp[] = {(char *)CBM_BIN, "cli", "list_projects", NULL};
    (void)run(lp);
    return 0;
}

static int launchctl_job(const char *verb, bool dash_k) {
    char target[256];
    snprintf(target, sizeof target, "gui/%u/%s", (unsigned)getuid(), LABEL);
    if (dash_k) {
        char *argv[] = {(char *)LAUNCHCTL, (char *)verb, "-k", target, NULL};
        return run(argv);
    }
    char *argv[] = {(char *)LAUNCHCTL, (char *)verb, target, NULL};
    return run(argv);
}

/* `start` must bootstrap the plist into the domain: after `stop` (bootout) the
 * job is gone, so `kickstart` would fail with "service not found". nix-darwin
 * installs the agent at ~/Library/LaunchAgents/<LABEL>.plist. */
static int cmd_start(void) {
    const char *home = getenv("HOME");
    if (!home || !*home) {
        fprintf(stderr, "%s: $HOME unset\n", prog);
        return 1;
    }
    char domain[64];
    snprintf(domain, sizeof domain, "gui/%u", (unsigned)getuid());
    char plist[4096];
    snprintf(plist, sizeof plist, "%s/Library/LaunchAgents/%s.plist", home, LABEL);
    char *argv[] = {(char *)LAUNCHCTL, "bootstrap", domain, plist, NULL};
    return run(argv);
}

static int cmd_logs(void) {
    const char *home = getenv("HOME");
    if (!home) {
        home = "";
    }
    char out[4096];
    char err[4096];
    snprintf(out, sizeof out, "%s/Library/Logs/%s.out.log", home, LABEL);
    snprintf(err, sizeof err, "%s/Library/Logs/%s.err.log", home, LABEL);
    char *argv[] = {(char *)TAIL, "-n", "200", "-F", out, err, NULL};
    execvp(argv[0], argv);
    fprintf(stderr, "%s: exec tail: %s\n", prog, strerror(errno));
    return 127;
}

static void usage(void) {
    fprintf(stderr,
            "usage: %s <command>\n"
            "  status              launchd state, port listener, indexed projects\n"
            "  flush  [path]       persist the index artifact for a repo\n"
            "  commit [-m msg] [path]  flush, then git add/commit .codebase-memory\n"
            "  start | stop | restart  control the launchd user agent\n"
            "  logs                tail -F the daemon logs\n",
            prog);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        usage();
        return 2;
    }
    const char *cmd = argv[1];
    if (strcmp(cmd, "status") == 0) {
        return cmd_status();
    }
    if (strcmp(cmd, "flush") == 0) {
        return cmd_flush(argc - 2, argv + 2);
    }
    if (strcmp(cmd, "commit") == 0) {
        return cmd_commit(argc - 2, argv + 2);
    }
    if (strcmp(cmd, "restart") == 0) {
        return launchctl_job("kickstart", true);
    }
    if (strcmp(cmd, "start") == 0) {
        return cmd_start();
    }
    if (strcmp(cmd, "stop") == 0) {
        return launchctl_job("bootout", false);
    }
    if (strcmp(cmd, "logs") == 0) {
        return cmd_logs();
    }
    fprintf(stderr, "%s: unknown command '%s'\n", prog, cmd);
    usage();
    return 2;
}
