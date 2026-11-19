/*
 * pam_tid_gate: Touch ID for sudo only while someone can reach this Mac's own
 * Touch ID readers.
 *
 * Apple's pam_tid shows its prompt on this Mac's screen and accepts only this
 * Mac's readers (not a reader on a Mac driving it through Universal Control).
 * When nobody is there, the prompt just waits. This module goes where
 * `pam_tid.so` would in /etc/pam.d/sudo_local: if any enabled rule says nobody
 * can reach the readers, it returns PAM_IGNORE and the stack goes on to the
 * password; otherwise it hands the call to pam_tid.
 *
 *   ssh      sudo runs under an sshd or sshd-session process, or has
 *            SSH_CONNECTION, SSH_CLIENT or SSH_TTY set
 *   locked   the console session's screen is locked
 *   console  no logged-in session is on the console
 *   idle     no local keyboard or mouse input for idle= seconds
 *   uc       Universal Control is linked (its power assertion is held)
 *
 * Options: rules=<comma list> (default: all five), idle=<seconds> (default
 * 300, 0 turns the idle rule off), debug (print the decision on stderr). An
 * option that doesn't parse keeps its default. A state that cannot be read
 * counts toward the password, never Touch ID, except the Universal Control
 * check, which counts as not linked.
 *
 * It calls no libpam function, so the only libpam in the process is the system
 * one sudo loaded. OpenPAM's headers supply the types and constants.
 */
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>
#include <unistd.h>

#define PAM_SM_AUTH
#include <security/pam_modules.h>

#define PAM_TID_PATH "/usr/lib/pam/pam_tid.so.2"
#define UC_ASSERTION_PREFIX "com.apple.universalcontrol."
#define DEFAULT_IDLE_SECONDS 300

enum {
  RULE_SSH = 1u << 0,
  RULE_LOCKED = 1u << 1,
  RULE_CONSOLE = 1u << 2,
  RULE_IDLE = 1u << 3,
  RULE_UC = 1u << 4,
  RULE_COUNT = 5,
  RULE_ALL = (1u << RULE_COUNT) - 1,
};

static const char *const rule_names[RULE_COUNT] = {"ssh", "locked", "console",
                                                   "idle", "uc"};

struct options {
  unsigned rules;
  long idle;
  bool debug;
};

/* An unknown name or an empty list keeps every rule: a typo must not turn
 * rules off and leave Touch ID where nobody can answer it. */
static unsigned parse_rules(const char *list) {
  unsigned rules = 0;
  char buf[128];
  if (strlcpy(buf, list, sizeof buf) >= sizeof buf)
    return RULE_ALL;
  char *save = NULL;
  for (char *t = strtok_r(buf, ",", &save); t; t = strtok_r(NULL, ",", &save)) {
    unsigned bit = 0;
    for (int i = 0; i < RULE_COUNT; i++)
      if (strcmp(t, rule_names[i]) == 0)
        bit = 1u << i;
    if (!bit)
      return RULE_ALL;
    rules |= bit;
  }
  return rules ? rules : RULE_ALL;
}

/* A value that isn't a whole number of seconds keeps the default. */
static long parse_idle(const char *value) {
  char *end = NULL;
  long idle = strtol(value, &end, 10);
  if (end == value || *end != '\0' || idle < 0)
    return DEFAULT_IDLE_SECONDS;
  return idle;
}

static struct options parse_options(int argc, const char **argv) {
  struct options o = {RULE_ALL, DEFAULT_IDLE_SECONDS, false};
  for (int i = 0; i < argc && argv[i]; i++) {
    if (strcmp(argv[i], "debug") == 0)
      o.debug = true;
    else if (strncmp(argv[i], "idle=", 5) == 0)
      o.idle = parse_idle(argv[i] + 5);
    else if (strncmp(argv[i], "rules=", 6) == 0)
      o.rules = parse_rules(argv[i] + 6);
  }
  return o;
}

static bool cf_true(CFTypeRef v) {
  return v && CFGetTypeID(v) == CFBooleanGetTypeID() &&
         CFBooleanGetValue((CFBooleanRef)v);
}

static bool has_env(const char *name) {
  const char *v = getenv(name);
  return v && *v;
}

/* sudo's own environment is still its caller's while PAM runs. A shell in a
 * tmux session started over ssh keeps these variables although tmux, not
 * sshd, is its ancestor. Setting them can only choose the password. */
static bool ssh_environment(void) {
  return has_env("SSH_CONNECTION") || has_env("SSH_CLIENT") ||
         has_env("SSH_TTY");
}

/* Walks the parent chain; sshd-session is OpenSSH 9.8+'s per-connection
 * process, sshd the listener and older per-connection processes. A parent
 * that can't be read (it exited mid-walk) counts as sshd. */
static bool under_sshd(void) {
  pid_t pid = getppid();
  for (int depth = 0; pid > 1 && depth < 64; depth++) {
    struct kinfo_proc kp;
    size_t len = sizeof kp;
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
    if (sysctl(mib, 4, &kp, &len, NULL, 0) != 0 || len == 0)
      return true;
    const char *comm = kp.kp_proc.p_comm;
    if (strcmp(comm, "sshd") == 0 || strcmp(comm, "sshd-session") == 0)
      return true;
    pid = kp.kp_eproc.e_ppid;
  }
  return false;
}

/* IOConsoleUsers lists the GUI sessions; the one on the console carries
 * CGSSessionScreenIsLocked while its screen is locked. */
static void console_state(bool *on_console, bool *locked) {
  *on_console = false;
  *locked = false;
  io_registry_entry_t root = IORegistryGetRootEntry(kIOMainPortDefault);
  if (root == MACH_PORT_NULL)
    return;
  CFTypeRef users = IORegistryEntryCreateCFProperty(
      root, CFSTR("IOConsoleUsers"), kCFAllocatorDefault, 0);
  IOObjectRelease(root);
  if (!users)
    return;
  if (CFGetTypeID(users) == CFArrayGetTypeID()) {
    CFArrayRef list = (CFArrayRef)users;
    for (CFIndex i = 0; i < CFArrayGetCount(list); i++) {
      CFTypeRef s = CFArrayGetValueAtIndex(list, i);
      if (CFGetTypeID(s) != CFDictionaryGetTypeID())
        continue;
      CFDictionaryRef session = (CFDictionaryRef)s;
      if (!cf_true(CFDictionaryGetValue(session,
                                        CFSTR("kCGSSessionOnConsoleKey"))) ||
          !cf_true(CFDictionaryGetValue(session,
                                        CFSTR("kCGSessionLoginDoneKey"))))
        continue;
      *on_console = true;
      *locked = cf_true(
          CFDictionaryGetValue(session, CFSTR("CGSSessionScreenIsLocked")));
      break;
    }
  }
  CFRelease(users);
}

/* Seconds since the last keyboard or mouse event, or -1 if unreadable.
 * Universal Control input from another Mac counts as an event here. */
static long idle_seconds(void) {
  io_service_t hid = IOServiceGetMatchingService(
      kIOMainPortDefault, IOServiceMatching("IOHIDSystem"));
  if (hid == MACH_PORT_NULL)
    return -1;
  CFTypeRef v = IORegistryEntryCreateCFProperty(hid, CFSTR("HIDIdleTime"),
                                                kCFAllocatorDefault, 0);
  IOObjectRelease(hid);
  long seconds = -1;
  if (v) {
    int64_t ns;
    if (CFGetTypeID(v) == CFNumberGetTypeID() &&
        CFNumberGetValue((CFNumberRef)v, kCFNumberSInt64Type, &ns))
      seconds = (long)(ns / 1000000000);
    CFRelease(v);
  }
  return seconds;
}

/* UniversalControl holds com.apple.universalcontrol.preventDisplaySleep
 * while linked to another Mac, whether or not its cursor is here. */
static bool universal_control_linked(void) {
  CFDictionaryRef by_pid = NULL;
  if (IOPMCopyAssertionsByProcess(&by_pid) != kIOReturnSuccess || !by_pid)
    return false;
  bool linked = false;
  CFIndex n = CFDictionaryGetCount(by_pid);
  const void **lists = calloc((size_t)n, sizeof *lists);
  if (lists) {
    CFDictionaryGetKeysAndValues(by_pid, NULL, lists);
    for (CFIndex i = 0; i < n && !linked; i++) {
      if (CFGetTypeID(lists[i]) != CFArrayGetTypeID())
        continue;
      CFArrayRef list = (CFArrayRef)lists[i];
      for (CFIndex j = 0; j < CFArrayGetCount(list) && !linked; j++) {
        CFTypeRef a = CFArrayGetValueAtIndex(list, j);
        if (CFGetTypeID(a) != CFDictionaryGetTypeID())
          continue;
        CFTypeRef name =
            CFDictionaryGetValue((CFDictionaryRef)a, kIOPMAssertionNameKey);
        linked = name && CFGetTypeID(name) == CFStringGetTypeID() &&
                 CFStringHasPrefix((CFStringRef)name,
                                   CFSTR(UC_ASSERTION_PREFIX));
      }
    }
    free(lists);
  }
  CFRelease(by_pid);
  return linked;
}

/* The enabled rules that hold right now; 0 means Touch ID. */
static unsigned password_reasons(const struct options *o, long *idle_out) {
  unsigned reasons = 0;
  if ((o->rules & RULE_SSH) && (ssh_environment() || under_sshd()))
    reasons |= RULE_SSH;
  bool on_console, locked;
  console_state(&on_console, &locked);
  if ((o->rules & RULE_CONSOLE) && !on_console)
    reasons |= RULE_CONSOLE;
  if ((o->rules & RULE_LOCKED) && locked)
    reasons |= RULE_LOCKED;
  long idle = idle_seconds();
  *idle_out = idle;
  if ((o->rules & RULE_IDLE) && o->idle > 0 && (idle < 0 || idle >= o->idle))
    reasons |= RULE_IDLE;
  if ((o->rules & RULE_UC) && universal_control_linked())
    reasons |= RULE_UC;
  return reasons;
}

static void describe(unsigned reasons, long idle, char *buf, size_t len) {
  if (!reasons) {
    snprintf(buf, len, "Touch ID (idle %lds)", idle);
    return;
  }
  strlcpy(buf, "password:", len);
  for (int i = 0; i < RULE_COUNT; i++)
    if (reasons & (1u << i)) {
      strlcat(buf, " ", len);
      strlcat(buf, rule_names[i], len);
    }
  char tail[32];
  snprintf(tail, sizeof tail, " (idle %lds)", idle);
  strlcat(buf, tail, len);
}

/* For the pam-tid-gate CLI: the decision for these module options. */
unsigned pam_tid_gate_explain(int argc, const char **argv, char *buf,
                              size_t len) {
  struct options o = parse_options(argc, argv);
  long idle;
  unsigned reasons = password_reasons(&o, &idle);
  describe(reasons, idle, buf, len);
  return reasons;
}

typedef int (*pam_sm_fn)(pam_handle_t *, int, int, const char **);

static int call_pam_tid(const char *symbol, pam_handle_t *pamh, int flags) {
  static void *pam_tid;
  if (!pam_tid)
    pam_tid = dlopen(PAM_TID_PATH, RTLD_NOW | RTLD_LOCAL);
  if (!pam_tid)
    return PAM_IGNORE;
  pam_sm_fn fn = (pam_sm_fn)dlsym(pam_tid, symbol);
  if (!fn)
    return PAM_IGNORE;
  static const char *no_args[] = {NULL};
  return fn(pamh, flags, 0, no_args);
}

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc,
                                   const char **argv) {
  struct options o = parse_options(argc, argv);
  long idle;
  unsigned reasons = password_reasons(&o, &idle);
  if (o.debug) {
    char buf[160];
    describe(reasons, idle, buf, sizeof buf);
    fprintf(stderr, "pam_tid_gate: %s\n", buf);
  }
  if (reasons)
    return PAM_IGNORE;
  return call_pam_tid("pam_sm_authenticate", pamh, flags);
}

/* Passed through so the stack behaves as it did with pam_tid on this line. */
PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc,
                              const char **argv) {
  (void)argc;
  (void)argv;
  return call_pam_tid("pam_sm_setcred", pamh, flags);
}
