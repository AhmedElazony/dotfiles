-- Environment variables
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Cursor
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "capitaine-cursors")
hl.env("HYPRCURSOR_THEME", "capitaine-cursors")

-- XDG
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- QT
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
-- hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")

-- hl.env("HYPRSHOT_DIR", "~/Pictures/Screenshots")

-- Electron apps:
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "x11")
hl.env("ELECTRON_FLAGS_FILE", "~/.config/electron-flags.conf")

-- Themes
hl.env("GTK_APPLICATION_PREFER_DARK_THEME", "1")

-- Universal NVIDIA Wayland environment variables
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Hardware cursor fix (needed for most NVIDIA cards on Wayland)
-- hl.env("WLR_NO_HARDWARE_CURSORS", "1")

-- NVIDIA offloading (for hybrid/optimus systems)
-- hl.env("__NV_PRIME_RENDER_OFFLOAD", "1")
-- hl.env("__VK_LAYER_NV_optimus", "1")

-- Additional compatibility
-- hl.env("WLR_DRM_NO_ATOMIC", "1")
-- hl.env("NVIDIA_WAYLAND", "1")
-- hl.env("GBM_BACKEND", "nvidia-drm")