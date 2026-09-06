-- Autostart (exec-once equivalent)
-- https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
    hl.exec_cmd("qs")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("kdeconnect-indicator")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("clipse -listen")
    -- get root password for gui apps
    -- hl.exec_cmd("usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("lxqt-policykit-agent")

    -- Fix monitor after suspend
    hl.exec_cmd('hyprctl keyword monitor "HDMI-A-1,1920x1080@144.01,auto,auto"')

    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/xdg_portal.sh")
    hl.exec_cmd(os.getenv("HOME") .. "/.local/lib/import_env tmux")
    hl.exec_cmd("hypridle")

    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/hyprlock-spotlight.sh")

    -- hl.exec_cmd("swaync")
end)