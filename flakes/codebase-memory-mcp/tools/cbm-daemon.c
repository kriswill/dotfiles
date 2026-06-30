/*
 * cbm-daemon — launchd-friendly foreground wrapper for codebase-memory-mcp's
 * HTTP UI / watcher daemon.
 *
 * Why this exists: `codebase-memory-mcp` has no daemon mode. Its HTTP UI and
 * git-watcher run as background threads inside the normal stdio MCP server,
 * which blocks in cbm_mcp_server_run() until stdin hits EOF (or SIGTERM). Under
 * launchd, stdin is /dev/null, so the process would read EOF and exit at once.
 *
 * The fix is to hand the server a stdin that never reaches EOF: a FIFO opened
 * O_RDWR (this process is therefore also a writer, so reads block forever). We
 * dup2 it onto fd 0 and exec the server in the foreground, so launchd tracks
 * the real daemon PID directly — KeepAlive restarts it on crash, and a SIGTERM
 * from `launchctl bootout` / `kickstart -k` reaches the server's own graceful
 * signal handler.
 *
 * Config (env, with compiled-in fallbacks):
 *   CBM_BIN         path to codebase-memory-mcp   (default: -DCBM_BIN_DEFAULT)
 *   CBM_PORT        HTTP UI port                  (default: 9749)
 *   CBM_STDIN_FIFO  FIFO path  (default: $HOME/.cache/codebase-memory-mcp/cbm-daemon.stdin)
 */
#include <errno.h>
#include <fcntl.h>
#include <libgen.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef CBM_BIN_DEFAULT
#define CBM_BIN_DEFAULT "codebase-memory-mcp"
#endif

/* mkdir -p: create every component of `path`. EEXIST is success. */
static int mkdirs(const char *path) {
    char tmp[4096];
    size_t len = strlen(path);
    if (len == 0 || len >= sizeof tmp) {
        errno = ENAMETOOLONG;
        return -1;
    }
    memcpy(tmp, path, len + 1);
    for (char *p = tmp + 1; *p; p++) {
        if (*p != '/') {
            continue;
        }
        *p = '\0';
        if (mkdir(tmp, 0700) != 0 && errno != EEXIST) {
            return -1;
        }
        *p = '/';
    }
    if (mkdir(tmp, 0700) != 0 && errno != EEXIST) {
        return -1;
    }
    return 0;
}

int main(void) {
    const char *bin = getenv("CBM_BIN");
    if (!bin || !*bin) {
        bin = CBM_BIN_DEFAULT;
    }
    const char *port = getenv("CBM_PORT");
    if (!port || !*port) {
        port = "9749";
    }

    char fifobuf[4096];
    const char *fifo = getenv("CBM_STDIN_FIFO");
    if (!fifo || !*fifo) {
        const char *home = getenv("HOME");
        if (!home || !*home) {
            home = "/tmp";
        }
        snprintf(fifobuf, sizeof fifobuf, "%s/.cache/codebase-memory-mcp/cbm-daemon.stdin", home);
        fifo = fifobuf;
    }

    /* mkdir -p dirname(fifo); dirname() may scribble on its argument. */
    char dirbuf[4096];
    snprintf(dirbuf, sizeof dirbuf, "%s", fifo);
    const char *dir = dirname(dirbuf);
    if (mkdirs(dir) != 0) {
        fprintf(stderr, "cbm-daemon: mkdir %s: %s\n", dir, strerror(errno));
        return 1;
    }

    /* Ensure the FIFO exists; recreate it if a stale non-pipe is in the way. */
    struct stat st;
    if (stat(fifo, &st) != 0) {
        if (mkfifo(fifo, 0600) != 0 && errno != EEXIST) {
            fprintf(stderr, "cbm-daemon: mkfifo %s: %s\n", fifo, strerror(errno));
            return 1;
        }
    } else if (!S_ISFIFO(st.st_mode)) {
        (void)unlink(fifo);
        if (mkfifo(fifo, 0600) != 0) {
            fprintf(stderr, "cbm-daemon: mkfifo %s: %s\n", fifo, strerror(errno));
            return 1;
        }
    }

    /* O_RDWR: holding a write end open means the MCP read loop never sees EOF. */
    int fd = open(fifo, O_RDWR);
    if (fd < 0) {
        fprintf(stderr, "cbm-daemon: open %s: %s\n", fifo, strerror(errno));
        return 1;
    }
    if (fd != STDIN_FILENO) {
        if (dup2(fd, STDIN_FILENO) < 0) {
            fprintf(stderr, "cbm-daemon: dup2: %s\n", strerror(errno));
            return 1;
        }
        (void)close(fd);
    }

    char portarg[64];
    snprintf(portarg, sizeof portarg, "--port=%s", port);

    execlp(bin, bin, "--ui=true", portarg, (char *)NULL);
    fprintf(stderr, "cbm-daemon: exec %s: %s\n", bin, strerror(errno));
    return 127;
}
