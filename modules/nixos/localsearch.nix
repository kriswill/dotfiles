{
  flake.modules.nixos.localsearch =
    # Registers the Tracker3/LocalSearch D-Bus service so GTK file managers
    # (Nautilus) can D-Bus-activate it for search indexing, instead of
    # warning "name is not activatable".
    {
      services.gnome.localsearch.enable = true;
    };
}
