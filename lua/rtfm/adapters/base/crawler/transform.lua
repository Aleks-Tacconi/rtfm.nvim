local path_utils = require("rtfm.path")

local M = {}

--- Derives a section name from a fragment and fallback heuristics.
--- @param section string
--- @param rule table
--- @return string|nil
function M.derive_section_name(section, rule)
	local output = rule:apply(section)
	local name = output and output[1]
	if not name or name == "" then
		local fallback_id = section:match(' id="([^"]+)"') or section:match(" id='([^']+)'")
		if fallback_id and fallback_id ~= "" then
			return vim.trim(fallback_id)
		end

		local desc_class =
			section:match('<span class="sig%-prename descclassname"><span class="pre">(.-)</span></span>')
		local desc_name = section:match('<span class="sig%-name descname"><span class="pre">(.-)</span></span>')
		if desc_name and desc_name ~= "" then
			return vim.trim((desc_class or "") .. desc_name)
		end

		return nil
	end

	return vim.trim(name)
end

--- Normalizes a section name for a stable output path.
--- @param source string
--- @param section_name string
--- @return string|nil
function M.normalize_section_name(source, section_name)
	local normalized = section_name
	local prefix = source .. "."

	if normalized:sub(1, #prefix) == prefix then
		normalized = normalized:sub(#prefix + 1)
	end

	normalized = normalized:gsub("%._+", "__")
	normalized = normalized:gsub("%.", "__")

	if normalized == "" then
		return nil
	end

	return normalized
end

--- Returns the default relative output path for a section.
--- @param ctx table
--- @return string
local function default_relative_path(ctx)
	local source_key = ctx.source_name:gsub("%.", "/")
	return string.format("%s/%s", source_key, ctx.normalized_name)
end

--- Returns the validated relative output path for a section.
--- @param crawler table
--- @param ctx table
--- @return string
function M.relative_output_path(crawler, ctx)
	local relative_path = default_relative_path(ctx)
	if crawler.path_mapper then
		relative_path = crawler.path_mapper(ctx)
	end

	return path_utils.normalize(relative_path)
end

return M
