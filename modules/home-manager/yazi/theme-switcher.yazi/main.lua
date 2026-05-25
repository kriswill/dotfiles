-- Kanagawa theme switcher.
--
-- Presents a which-key menu of the installed flavors and persists the choice to
-- yazi's state dir (~/.local/state/yazi/theme.toml, an out-of-store symlink the
-- nix config points $XDG_CONFIG_HOME/yazi/theme.toml at). yazi reads
-- theme.toml's [flavor] only at startup and offers no live flavor reload, so the
-- selection takes effect on the next launch — hence the notify.

local THEMES = {
	{ on = "k", flavor = "kanagawa-kris", desc = "Kanagawa Kris" },
	{ on = "w", flavor = "kanagawa-wave", desc = "Kanagawa Wave" },
	{ on = "d", flavor = "kanagawa-dragon", desc = "Kanagawa Dragon" },
	{ on = "l", flavor = "kanagawa-lotus", desc = "Kanagawa Lotus (light)" },
}

-- Resolve ~/.local/state/yazi, honoring XDG_STATE_HOME. os.getenv is pure (no
-- I/O), so it's safe in the async entry context.
local function state_dir()
	local base = os.getenv("XDG_STATE_HOME")
	if not base or base == "" then
		base = (os.getenv("HOME") or "") .. "/.local/state"
	end
	return base .. "/yazi"
end

return {
	entry = function()
		local cands = {}
		for i, t in ipairs(THEMES) do
			cands[i] = { on = t.on, desc = t.desc }
		end

		local idx = ya.which({ cands = cands })
		if not idx then
			return
		end

		local flavor = THEMES[idx].flavor
		local dir = state_dir()
		local body = string.format('[flavor]\ndark = "%s"\nlight = "%s"\n', flavor, flavor)

		-- Ensure the state dir exists (it normally does, seeded by activation).
		fs.create("dir_all", Url(dir))

		local ok, err = fs.write(Url(dir .. "/theme.toml"), body)
		if not ok then
			ya.notify({
				title = "Theme",
				content = "Failed to save theme: " .. tostring(err),
				timeout = 5,
				level = "error",
			})
			return
		end

		ya.notify({
			title = "Theme",
			content = "Set " .. flavor .. ". Restart yazi to apply.",
			timeout = 5,
			level = "info",
		})
	end,
}
