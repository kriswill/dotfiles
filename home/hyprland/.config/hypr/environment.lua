-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Cursor: rose-pine-hyprcursor (native hyprcursor format — BreezeX cursor shape
-- recolored in the muted Rose Pine palette). Installed system-wide via
-- pkgs.rose-pine-hyprcursor in nixosConfigurations/nebula/configuration.nix.
-- Hyprland renders the compositor cursor from HYPRCURSOR_THEME across the whole
-- desktop (including over XWayland windows). The theme is hyprcursor-only, so
-- client-side-cursor apps (XWayland: Steam) get the same BreezeX Rose Pine shape
-- in Xcursor format via pkgs.rose-pine-cursor + XCURSOR_THEME.
-- (GTK uses gtk-cursor-theme-name in ~/.config/gtk-*/settings.ini instead.)
hl.env("HYPRCURSOR_THEME", "rose-pine-hyprcursor")
hl.env("HYPRCURSOR_SIZE", "48")
hl.env("XCURSOR_THEME", "BreezeX-RosePine-Linux")
hl.env("XCURSOR_SIZE", "48")

-- XWayland apps can't do per-monitor fractional scaling. With force_zero_scaling
-- (below) they render 1:1 (crisp) instead of being bitmap-upscaled (blurry), but
-- then look tiny on a fractional monitor. Compensate per-app: Steam reads this and
-- scales its own UI back up to match DP-3's 1.33x. (Other X11 apps that look small
-- may need GDK_DPI_SCALE / QT_SCALE_FACTOR; don't set those globally — they'd
-- double-apply on native-Wayland apps.)
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.33")

----------------------
----- XWAYLAND -----
----------------------

-- Render X11 client buffers at scale 1 (no fractional bitmap upscale = no jaggy
-- text). See env note above re: per-app size compensation.
hl.config({ xwayland = { force_zero_scaling = true } })

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
