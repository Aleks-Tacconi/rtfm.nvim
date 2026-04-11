local utils = require("rtfm.utils")

local M = {}

--- Returns a cleaned title for index entries.
--- @param title string
--- @return string
local function normalize_title(title)
	local normalized = title:gsub("¶", "")
	normalized = normalized:gsub("&#x[bB]6;", "")
	normalized = normalized:gsub("&#182;", "")
	normalized = normalized:gsub("%s+", " ")
	return vim.trim(normalized)
end

--- Returns the display title for an index entry.
--- @param ctx table
--- @param relative_path string
--- @return string
local function display_title(ctx, relative_path)
	if ctx.heading_text and ctx.heading_text ~= "" then
		return normalize_title(ctx.heading_text)
	end

	if ctx.section_id and ctx.section_id ~= "" then
		return ctx.section_id
	end

	return relative_path:match("([^/]+)$") or relative_path
end

--- Registers an extracted section in the scope index.
--- @param entries table[]
--- @param relative_path string
--- @param ctx table
--- @return nil
function M.register_index_entry(entries, relative_path, ctx)
	table.insert(entries, {
		path = relative_path,
		title = display_title(ctx, relative_path),
	})
end

--- Writes the scope index file.
--- @param output_path string
--- @param entries table[]
--- @return nil
function M.write_index(output_path, entries)
	if #entries == 0 then
		return
	end

	local lines = {}
	for index, entry in ipairs(entries) do
		table.insert(lines, string.format("%d. %s - %s.md", index, entry.title, entry.path))
	end

	utils.write_file(output_path .. "/_index.md", table.concat(lines, "\n") .. "\n")
end

return M
