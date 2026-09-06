-- Window and workspace rules
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Ignore maximize requests from apps. You'll probably like this.
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

-- ensure you have a floating window class set if you want this behavior
hl.window_rule({ match = { class = "(clipse)" }, float = true })
-- set the size of the window as necessary
hl.window_rule({ match = { class = "(clipse)" }, size = { 622, 652 } })
-- center the window on spawn
hl.window_rule({ match = { class = "(blueman-manager)" }, float = true })
hl.window_rule({ match = { class = "(pavucontrol)" }, float = true })

-- Better support for layer shell applications
hl.layer_rule({
	name = "wlogout-blur",
	match = { namespace = "wlogout" },
	blur = true,
	ignore_alpha = 0.5,
})

-- Essential floating dialogs with proper sizing
hl.window_rule({
	match = { class = "^(.*[Dd]ialog.*)$" },
	float = true,
	size = { 600, 400 },
	center = true,
})
hl.window_rule({ match = { title = "^(.*[Dd]ialog.*)$" }, float = true })

-- File dialogs - most important ones
hl.window_rule({ match = { title = "^(Open File)$" }, float = true })
hl.window_rule({ match = { title = "^(Save File)$" }, float = true })
hl.window_rule({ match = { title = "^(Select a File)$" }, float = true })
hl.window_rule({ match = { title = "^(Open Folder)$" }, float = true })
hl.window_rule({
	match = { title = "^(Open File|Save File|Select a File|Open Folder)$" },
	size = { 800, 600 },
	center = true,
})

-- Portal dialogs (essential for file operations)
hl.window_rule({
	match = { class = "^(xdg-desktop-portal-gtk)$" },
	float = true,
	size = { 700, 500 },
	center = true,
})

-- Essential system dialogs
hl.window_rule({ match = { class = "^(notification)$" }, float = true })
hl.window_rule({ match = { class = "^(confirmreset)$" }, float = true })
hl.window_rule({ match = { class = "^(notification|confirmreset)$" }, size = { 400, 200 }, center = true })

-- Browser specific (if you use Firefox)
hl.window_rule({ match = { class = "^(firefox)$", title = "^(Library|File Upload)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(firefox)$", title = "^(Library)$" }, size = { 900, 600 } })
hl.window_rule({ match = { class = "^(firefox)$", title = "^(File Upload)$" }, size = { 500, 400 } })

