/*
 * pam-tid-gate: whether sudo would use Touch ID or the password right now,
 * and which rules decided it.
 *
 *   pam-tid-gate [idle=N] [rules=a,b] [debug]
 *
 * Without options it uses the ones /etc/pam.d/sudo_local passes the module,
 * so the answer matches sudo's. Exit status: 0 for Touch ID, 1 for the
 * password, 2 if the module won't load.
 *
 * It loads the installed module and asks it, so the answer is that code's.
 * It cannot show the Touch ID prompt itself: pam_tid asks authd for the
 * com.apple.security.sudo right, which only an entitled client (sudo) gets.
 */
#include <dlfcn.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#ifndef MODULE_PATH
#error "MODULE_PATH must name the installed pam_tid_gate.so"
#endif
#define SUDO_LOCAL "/etc/pam.d/sudo_local"
#define MAX_OPTIONS 16

typedef unsigned (*explain_fn)(int, const char **, char *, size_t);

/* The arguments after pam_tid_gate.so on its sudo_local line. */
static int sudo_local_options(char *line, size_t len, const char **opts) {
  FILE *f = fopen(SUDO_LOCAL, "r");
  if (!f)
    return 0;
  int n = 0;
  while (fgets(line, (int)len, f)) {
    char *comment = strchr(line, '#');
    if (comment)
      *comment = '\0';
    if (!strstr(line, "pam_tid_gate.so"))
      continue;
    bool after_module = false;
    char *save = NULL;
    for (char *t = strtok_r(line, " \t\n", &save); t;
         t = strtok_r(NULL, " \t\n", &save)) {
      if (after_module && n < MAX_OPTIONS)
        opts[n++] = t;
      else if (strstr(t, "pam_tid_gate.so"))
        after_module = true;
    }
    break;
  }
  fclose(f);
  return n;
}

int main(int argc, char **argv) {
  if (argc > 1 &&
      (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0)) {
    printf("usage: pam-tid-gate [idle=N] [rules=a,b] [debug]\n"
           "Without options it uses the ones in " SUDO_LOCAL ".\n");
    return 0;
  }
  void *module = dlopen(MODULE_PATH, RTLD_NOW | RTLD_LOCAL);
  if (!module) {
    fprintf(stderr, "pam-tid-gate: %s\n", dlerror());
    return 2;
  }
  explain_fn explain = (explain_fn)dlsym(module, "pam_tid_gate_explain");
  if (!explain) {
    fprintf(stderr, "pam-tid-gate: %s\n", dlerror());
    return 2;
  }

  const char **opts = (const char **)argv + 1;
  int nopts = argc - 1;
  char line[512];
  const char *installed[MAX_OPTIONS];
  if (nopts == 0) {
    opts = installed;
    nopts = sudo_local_options(line, sizeof line, installed);
  }

  char decision[160];
  unsigned reasons = explain(nopts, opts, decision, sizeof decision);
  printf("%s\n", decision);
  return reasons ? 1 : 0;
}
