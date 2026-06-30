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

/* ── status rendering (colored, YAML-like) ──────────────────────────── */

static int g_color = 0;

#define COL(c) (g_color ? (c) : "")
#define A_RESET "\033[0m"
#define A_BOLD "\033[1m"
#define A_DIM "\033[2m"
#define A_RED "\033[31m"
#define A_GREEN "\033[32m"
#define A_YELLOW "\033[33m"
#define A_BLUE "\033[34m"
#define A_CYAN "\033[36m"

/* A YAML-style "<indent>key: value" line: cyan key, value column at indent+13. */
static void field(int indent, const char *key, const char *valcol, const char *val) {
    int pad = 12 - (int)strlen(key);
    if (pad < 1) {
        pad = 1;
    }
    printf("%*s%s%s%s:%*s%s%s%s\n", indent, "", COL(A_CYAN), key, COL(A_RESET), pad, "",
           COL(valcol), val, COL(A_RESET));
}

static void section(const char *name) {
    printf("  %s%s%s%s:\n", COL(A_BOLD), COL(A_BLUE), name, COL(A_RESET));
}

/* In a `launchctl list` plist dump, find the text after `"key" = `. */
static const char *plist_after(const char *buf, const char *key) {
    char needle[160];
    int len = snprintf(needle, sizeof needle, "\"%s\" = ", key);
    const char *p = strstr(buf, needle);
    return p ? p + len : NULL;
}
static int plist_num(const char *buf, const char *key, long *out) {
    const char *p = plist_after(buf, key);
    if (!p) {
        return -1;
    }
    *out = strtol(p, NULL, 10);
    return 0;
}
static int plist_str(const char *buf, const char *key, char *out, size_t n) {
    const char *p = plist_after(buf, key);
    if (!p || *p != '"') {
        return -1;
    }
    p++;
    size_t i = 0;
    while (*p && *p != '"' && i + 1 < n) {
        out[i++] = *p++;
    }
    out[i] = '\0';
    return 0;
}

/* Extract "key":"string" / "key":number from a flat JSON object substring. */
static int json_str(const char *obj, const char *key, char *out, size_t n) {
    char needle[160];
    snprintf(needle, sizeof needle, "\"%s\":\"", key);
    const char *p = strstr(obj, needle);
    if (!p) {
        return -1;
    }
    p += strlen(needle);
    size_t i = 0;
    while (*p && *p != '"' && i + 1 < n) {
        if (*p == '\\' && p[1]) {
            p++;
        }
        out[i++] = *p++;
    }
    out[i] = '\0';
    return 0;
}
static int json_num(const char *obj, const char *key, long *out) {
    char needle[160];
    snprintf(needle, sizeof needle, "\"%s\":", key);
    const char *p = strstr(obj, needle);
    if (!p) {
        return -1;
    }
    *out = strtol(p + strlen(needle), NULL, 10);
    return 0;
}

static void human_size(long bytes, char *out, size_t n) {
    double b = (double)bytes;
    const char *u[] = {"B", "KiB", "MiB", "GiB", "TiB"};
    size_t i = 0;
    while (b >= 1024.0 && i < 4) {
        b /= 1024.0;
        i++;
    }
    snprintf(out, n, "%.1f %s", b, u[i]);
}

static int cmd_status(void) {
    g_color = isatty(STDOUT_FILENO) && getenv("NO_COLOR") == NULL;
    const char *port = getenv("CBM_PORT");
    if (!port || !*port) {
        port = PORT_DEFAULT;
    }
    const char *home = getenv("HOME");
    char buf[1200];

    printf("%s%scodebase-memory-mcp%s\n", COL(A_BOLD), COL(A_BLUE), COL(A_RESET));

    /* ── daemon: parsed from `launchctl list <LABEL>` ── */
    section("daemon");
    char plist[8192];
    char *ll[] = {(char *)LAUNCHCTL, "list", (char *)LABEL, NULL};
    bool loaded = (capture(ll, plist, sizeof plist) == 0);
    long pid = -1;
    long lastexit = -1;
    char program[1024] = "";
    if (loaded) {
        (void)plist_num(plist, "PID", &pid);
        (void)plist_num(plist, "LastExitStatus", &lastexit);
        (void)plist_str(plist, "Program", program, sizeof program);
    }
    bool running = loaded && pid > 0;
    field(4, "status", running ? A_GREEN : A_RED,
          !loaded ? "not loaded" : (running ? "running" : "stopped"));
    if (running) {
        snprintf(buf, sizeof buf, "%ld", pid);
        field(4, "pid", A_YELLOW, buf);
    }

    char iarg[64];
    snprintf(iarg, sizeof iarg, "-iTCP:%s", port);
    char lpid[64] = "";
    char *ls[] = {(char *)LSOF, "-nP", iarg, "-sTCP:LISTEN", "-t", NULL};
    bool listening = (capture(ls, lpid, sizeof lpid) == 0 && lpid[0] != '\0');
    snprintf(buf, sizeof buf, "%s  %s", port, listening ? "listening" : "not listening");
    field(4, "port", listening ? A_GREEN : A_YELLOW, buf);

    if (loaded && lastexit >= 0) {
        snprintf(buf, sizeof buf, "%ld", lastexit);
        field(4, "last exit", lastexit == 0 ? A_GREEN : A_YELLOW, buf);
    }
    if (program[0]) {
        field(4, "program", A_DIM, program);
    }
    if (home) {
        snprintf(buf, sizeof buf, "%s/Library/Logs/%s.{out,err}.log", home, LABEL);
        field(4, "logs", A_DIM, buf);
    }

    /* ── projects: parsed from `cli list_projects` JSON ── */
    section("projects");
    char json[16384];
    char *lp[] = {(char *)CBM_BIN, "cli", "list_projects", NULL};
    if (capture(lp, json, sizeof json) != 0) {
        printf("    %s(unavailable)%s\n", COL(A_DIM), COL(A_RESET));
        return 0;
    }
    const char *p = strchr(json, '[');           /* skips any leading log line */
    const char *end = p ? strchr(p, ']') : NULL; /* flat objects → first ] ends array */
    int count = 0;
    while (p && end) {
        const char *ob = strchr(p, '{');
        if (!ob || ob > end) {
            break;
        }
        const char *oe = strchr(ob, '}');
        if (!oe || oe > end) {
            break;
        }
        char obj[2048];
        size_t len = (size_t)(oe - ob + 1);
        if (len >= sizeof obj) {
            len = sizeof obj - 1;
        }
        memcpy(obj, ob, len);
        obj[len] = '\0';

        char name[512] = "";
        char path[1024] = "";
        char human[64];
        long nodes = 0;
        long edges = 0;
        long size = 0;
        (void)json_str(obj, "name", name, sizeof name);
        (void)json_str(obj, "root_path", path, sizeof path);
        (void)json_num(obj, "nodes", &nodes);
        (void)json_num(obj, "edges", &edges);
        (void)json_num(obj, "size_bytes", &size);
        human_size(size, human, sizeof human);

        printf("    %s%s%s:\n", COL(A_GREEN), name[0] ? name : "(unknown)", COL(A_RESET));
        if (path[0]) {
            field(6, "path", A_DIM, path);
        }
        snprintf(buf, sizeof buf, "%ld", nodes);
        field(6, "nodes", A_YELLOW, buf);
        snprintf(buf, sizeof buf, "%ld", edges);
        field(6, "edges", A_YELLOW, buf);
        field(6, "size", A_YELLOW, human);
        count++;
        p = oe + 1;
    }
    if (count == 0) {
        printf("    %s(none indexed)%s\n", COL(A_DIM), COL(A_RESET));
    }
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

/* One usage row: cyan command, dim args, description aligned at column 24. */
static void usage_row(const char *cmd, const char *args, const char *desc) {
    int vis = (int)strlen(cmd) + ((args && args[0]) ? 1 + (int)strlen(args) : 0);
    int pad = 24 - vis;
    if (pad < 2) {
        pad = 2;
    }
    if (args && args[0]) {
        fprintf(stderr, "  %s%s%s %s%s%s%*s%s\n", COL(A_CYAN), cmd, COL(A_RESET), COL(A_DIM), args,
                COL(A_RESET), pad, "", desc);
    } else {
        fprintf(stderr, "  %s%s%s%*s%s\n", COL(A_CYAN), cmd, COL(A_RESET), pad, "", desc);
    }
}

static void usage(void) {
    g_color = isatty(STDERR_FILENO) && getenv("NO_COLOR") == NULL;
    fprintf(stderr, "%s%scbm-ctl%s %s— control the codebase-memory-mcp daemon%s\n\n", COL(A_BOLD),
            COL(A_BLUE), COL(A_RESET), COL(A_DIM), COL(A_RESET));
    fprintf(stderr, "%susage:%s cbm-ctl <command>\n\n", COL(A_DIM), COL(A_RESET));
    usage_row("status", "", "launchd state, port listener, indexed projects");
    usage_row("flush", "[path]", "persist the index artifact for a repo");
    usage_row("commit", "[-m msg] [path]", "flush, then git add/commit .codebase-memory");
    usage_row("start | stop | restart", "", "control the launchd user agent");
    usage_row("logs", "", "tail -F the daemon logs");
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
