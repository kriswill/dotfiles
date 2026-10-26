# On Linux, patch btop (./btop-largest-l3.patch) to colour the CPU box's core
# labels (C0, C1, …) of the CPUs sharing the largest L3 cache, in the colour of
# the memory box's Cached meter. On an AMD X3D part those are the 3D V-Cache
# CCD's CPUs: nebula's 9900X3D has 96 MB of L3 on 0-5,12-17 and 32 MB on the
# rest, which is where programs.battlenet.cpus pins WoW. btop itself knows
# nothing about cache topology. The sizes come from sysfs
# (cpu*/cache/index*/size, at level 3), read once; when every CPU's L3 is the
# same size, nothing changes.
#
# On darwin, pass btop through untouched: there is no sysfs, so the patch
# would only cost a source build.
_final: prev: {
  btop =
    if prev.stdenv.hostPlatform.isLinux then
      prev.btop.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./btop-largest-l3.patch ];
      })
    else
      prev.btop;
}
