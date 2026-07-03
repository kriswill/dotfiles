{
  # Helium browser — all Helium-specific config lives under modules/nixos/helium/.
  # Files here all contribute to flake.modules.nixos.helium (a deferredModule),
  # so they merge into one module. Add siblings (policies.nix, sync.nix, …) freely.
  #
  # NOT declaratively manageable (no Chromium policy key exists):
  #   * Per-extension keyboard shortcuts. They live only in mutable profile state
  #     (~/.config/net.imput.helium/Default/Preferences → "extensions.commands"
  #     and "extensions.settings.<id>.commands.*"), are set by hand at
  #     helium://extensions/shortcuts, and would have to be captured via a future
  #     sync.nix (selective Preferences backup), not policy. Current bindings:
  #     Dark Reader toggle=Alt+Shift+D, addSite=Alt+Shift+A; 1Password
  #     _execute_action=Ctrl+Shift+X, lock=Ctrl+Shift+L; uBlock Origin all unbound.
  flake.modules.nixos.helium =
    _:
    {
      programs.helium.enable = true; # upstream programs.helium module
    };
}
