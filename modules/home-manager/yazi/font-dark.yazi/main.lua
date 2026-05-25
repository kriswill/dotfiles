-- Override of yazi's built-in `font` previewer.
-- Mirrors the preset, except: transparent background (PNG, `xc:none`) with
-- glyphs colored to contrast the terminal background (via `rt.term.light`),
-- so the preview blends in on both light and dark terminals. The preset's
-- `64` pointsize is also written as the string `"64"` (Command:arg takes
-- strings), and the second `err` local is renamed, to type-check clean.

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

	-- yazi exposes no general "foreground" theme field, so key the glyph
	-- color off the terminal's light/dark mode: near-black on light
	-- terminals, kanagawa fujiWhite on dark ones.
	local fill = rt.term.light and "#181616" or "#c5c9c5"

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
