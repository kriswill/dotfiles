# Store deduplication off the build path (report P13, docs/nrs-pipeline.html).
# snowglobe sets auto-optimise-store = true (a setDefault, which a plain
# assignment outranks), so every file a build or substitution writes is
# hashed and hard-linked into /nix/store/.links as it lands, on the critical
# path of every nrs. nix.optimise does the same deduplication on a timer
# instead: weekly, early Sunday, after that night's nix-gc (00:00, see
# ./generations.nix), so it doesn't hash files the GC is about to delete.
# nix-store --optimise skips files whose inode is already in .links
# (loadInodeHash), so a run only hashes what is new since the last one.
# Persistent (the module's default): a run missed while off happens at the
# next boot.
{
  flake.modules.nixos.store-optimise = {
    nix.settings.auto-optimise-store = false;
    nix.optimise = {
      automatic = true;
      dates = [ "Sun 04:00" ];
    };
  };
}
