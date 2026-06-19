# Format-preserving TOML value setter, built on tomlkit (AST round-trip — keeps
# comments, key order, indentation, and number formatting; only the targeted
# value changes). Used by the Hyprland "toggle gaps" keybind to flip Noctalia's
# `[shell.screen_corners].enabled` without text-munging settings.toml.
#
#   usage: toml-set <file> <dotted.key.path> <value>
#   e.g.   toml-set ~/.local/state/noctalia/settings.toml shell.screen_corners.enabled false
#
# Value typing is inferred: true/false -> bool, ints -> int, floats -> float,
# everything else -> string.
#
# The write is ATOMIC: serialize to a temp file in the same directory, then
# os.replace() it over the target (an atomic rename on the same filesystem).
# This matters for live-watched config files like Noctalia's settings.toml — an
# in-place rewrite can be observed half-written by the app's file watcher, which
# in this Noctalia build triggers a destructive partial re-save (it clobbered
# settings.toml down to a single table). A rename swaps a complete inode in, so
# the watcher only ever sees the finished file. (Verified 2026-06-19.)
{ writers, python3Packages }:
writers.writePython3Bin "toml-set"
  {
    libraries = [ python3Packages.tomlkit ];
  }
  ''
    import os
    import stat
    import sys
    import tempfile

    import tomlkit


    def coerce(value):
        if value == "true":
            return True
        if value == "false":
            return False
        try:
            return int(value)
        except ValueError:
            pass
        try:
            return float(value)
        except ValueError:
            pass
        return value


    def atomic_write(path, text):
        directory = os.path.dirname(os.path.abspath(path))
        mode = stat.S_IMODE(os.stat(path).st_mode)
        fd, tmp = tempfile.mkstemp(dir=directory, prefix=".toml-set.")
        try:
            with os.fdopen(fd, "w") as handle:
                handle.write(text)
            os.chmod(tmp, mode)
            os.replace(tmp, path)
        except BaseException:
            os.unlink(tmp)
            raise


    def main():
        if len(sys.argv) != 4:
            sys.exit("usage: toml-set <file> <dotted.key.path> <value>")
        path, key, value = sys.argv[1], sys.argv[2], sys.argv[3]
        with open(path) as handle:
            doc = tomlkit.parse(handle.read())
        node = doc
        parts = key.split(".")
        for part in parts[:-1]:
            node = node[part]
        node[parts[-1]] = coerce(value)
        atomic_write(path, tomlkit.dumps(doc))


    if __name__ == "__main__":
        main()
  ''
