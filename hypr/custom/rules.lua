-- Enable blur for all windows (overrides hyprland/rules.lua defaults)
hl.window_rule({match = {class = "^()$", title = "^()$" }, no_blur = false })
hl.window_rule({match = {class = ".*" },                no_blur = false })

-- Special workspace gaps
hl.workspace_rule({ workspace = "special:special", gaps_out = 12 })

-- Quickshell layer rules
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:.*" }, ignore_alpha = 0.50 })
hl.layer_rule({ match = { namespace = "quickshell:.*" }, xray = false })

local workspace_rules = {
	{
		workspace = "s[false]",
		gaps_out = 30,
	},
	{
		workspace = "s[true]",
		gaps_out = 50,
	},
}

for _, rule in ipairs(workspace_rules) do
	hl.workspace_rule(rule)
end