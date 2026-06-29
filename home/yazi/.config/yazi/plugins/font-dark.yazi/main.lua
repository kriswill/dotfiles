-- Override of yazi's built-in `font` previewer.
-- Mirrors the preset, except: transparent background (PNG, `xc:none`) and
-- glyphs colored from the active flavor's foreground (`th.mgr.border_style`),
-- so the preview blends into the themed UI. The preset's `64` pointsize is
-- also written as the string `"64"` (Command:arg takes strings), and the
-- second `err` local is renamed, to type-check clean.

local TEXT = "ABCDEFGHIJKLM\nNOPQRSTUVWXYZ\nabcdefghijklm\nnopqrstuvwxyz\n1234567890\n!$&*()[]{}"

local M = {}

function M:peek(job)
	local start, cache = os.clock(), ya.file_cache(job)
	if not cache then
		return
	end

	local ok, err = self:preload(job)
	if not ok or err then
		-- `ya.preview_widget` renders a Renderable, an Error, or nil at runtime
		-- (yazi-plugin/src/utils/preview.rs), but the official types.yazi stub
		-- annotates only `Renderable|Renderable[]` — so passing `err` is a
		-- stub false-positive, not a defect.
		---@diagnostic disable-next-line: param-type-mismatch
		return ya.preview_widget(job, err)
	end

	ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))

	local _, show_err = ya.image_show(cache, job.area)
	ya.preview_widget(job, show_err)
end

function M:seek() end

function M:preload(job)
	local cache = ya.file_cache(job)
	if not cache or fs.cha(cache) then
		return true
	end

	-- Glyph color follows the active flavor's foreground. yazi exposes no
	-- flat palette, so read it off a component that carries the default fg
	-- (mgr.border_style); `:raw()` serializes the Style to a table whose
	-- `fg` is a "#RRGGBB" string. Fall back to fujiWhite if it's ever unset.
	local fill = th.mgr.border_style:raw().fg or "#c5c9c5"

	local status, err = Command("magick"):arg({
		"-size",
		"800x560",
		"-gravity",
		"center",
		"-font",
		tostring(job.file.path):gsub("\\", "\\\\"),
		"-pointsize",
		"64",
		"xc:none",
		"-fill",
		fill,
		"-annotate",
		"+0+0",
		TEXT,
		"PNG:" .. tostring(cache),
	}):status()

	if not status then
		return true, Err("Failed to start `magick`, error: %s", err)
	elseif not status.success then
		return false, Err("`magick` exited with error code: %s", status.code)
	else
		return true
	end
end

return M
