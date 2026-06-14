-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

local function bind(key, action, description)
	if description then
		hl.bind(key, action, { description = description })
	else
		hl.bind(key, action)
	end
end


local function rebind(key, action, description)
    hl.unbind(key)
    bind(key, action, description)
end

local function current_layout_name()
	local current = hl.get_config("general.layout")
	return type(current) == "table" and current.name or current
end

local function layout_bind(layout_name, cmd)
	return function()
		if current_layout_name() ~= layout_name then
			return
		end

		hl.dispatch(hl.dsp.layout(cmd))
	end
end

-- Scrolling
rebind("SUPER + mouse_up", layout_bind("scrolling", "focus d"), "[s] Move view (d)")
rebind("SUPER + mouse_down", layout_bind("scrolling", "focus u"), "[s] Move view (u)")
rebind("SUPER + SHIFT + mouse_up", hl.dsp.focus({ workspace = "r+1" }))
rebind("SUPER + SHIFT + mouse_down", hl.dsp.focus({ workspace = "r-1" }))
rebind("SUPER + ALT + mouse_up", layout_bind("scrolling", "swapcol l"), "[s] Swap row [u]")
rebind("SUPER + ALT + mouse_down", layout_bind("scrolling", "swapcol r"), "[s] Swap row [d]")
rebind("CTRL + SUPER + up", layout_bind("scrolling", "colresize -0.1"), "[s] Change size (-0.1)")
rebind("CTRL + SUPER + down", layout_bind("scrolling", "colresize +0.1"), "[s] Change size (+0.1)")
