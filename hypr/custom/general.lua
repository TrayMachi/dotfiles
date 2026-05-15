-- Monitor config (overrides auto-detection in hyprland/general.lua)
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@144.0",
    position = "0x0",
    scale = "1",
    bitdepth = 10
})
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@120.0",
    position = "0x1080",
    scale = "1"
})

-- Decoration overrides
hl.config({
    decoration = {
        active_opacity = 0.9,
        inactive_opacity = 0.7,
        fullscreen_opacity = 1.0,
        blur = {
            xray = false,
            size = 5,
            passes = 2,
            brightness = 0.9,
            contrast = 1.15,
            popups = true,
        },
    },
   	general = {
		layout = "scrolling",
    },
    input = {
		follow_mouse = 0,
	},
	scrolling = {
		column_width = 1,
		-- explicit_column_widths = 0.3, 0.8,
        direction = "down",
		fullscreen_on_one_column = false
	},
})