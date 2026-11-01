# The herdr TUI: our fork's own package (the herdr-cli input), stamped with a
# build identity. Upstream's build_info.rs reads these at compile time, so
# `herdr --version` / `herdr status` report e.g. 0.9.5-kriswill-custom.b52188b:
# a glance shows this is our fork build and which commit it carries. Any
# channel other than "preview" behaves exactly like stable (update checks
# compare the plain base version); the `channel:` line in status is the update
# channel and stays "stable" independently.
{ herdr, buildId }:
herdr.overrideAttrs (old: {
  env = (old.env or { }) // {
    HERDR_BUILD_CHANNEL = "kriswill-custom";
    HERDR_BUILD_ID = buildId;
  };
})
