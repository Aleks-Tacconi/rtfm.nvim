local M = {}

--- Returns the display width for text.
--- @param text string
--- @return integer
local function display_width(text)
	return vim.fn.strdisplaywidth(text)
end

--- Collapses whitespace so titles render on a single line.
--- @param text string|nil
--- @return string
local function sanitize_text(text)
	local value = (text or "-"):gsub("%s+", " ")
	return vim.trim(value)
end

--- Truncates text to a target display width.
--- @param text string
--- @param max_width integer
--- @return string
local function truncate_display(text, max_width)
	if max_width <= 0 then
		return ""
	end

	if display_width(text) <= max_width then
		return text
	end

	if max_width == 1 then
		return "…"
	end

	local target_width = max_width - display_width("…")
	local width = 0
	local result = {}
	local chars = vim.fn.strchars(text)

	for index = 0, chars - 1 do
		local char = vim.fn.strcharpart(text, index, 1)
		local char_width = display_width(char)
		if width + char_width > target_width then
			break
		end

		table.insert(result, char)
		width = width + char_width
	end

	return table.concat(result) .. "…"
end

--- Converts a display column to a byte index.
--- @param text string
--- @param column integer
--- @return integer
local function byte_index_from_display(text, column)
	if column <= 0 then
		return 0
	end

	local chars = vim.fn.strchars(text)
	local width = 0

	for index = 0, chars - 1 do
		if width >= column then
			return vim.str_byteindex(text, index)
		end

		width = width + display_width(vim.fn.strcharpart(text, index, 1))
	end

	return #text
end

--- Builds a line with left, centered, and right segments.
--- @param width integer
--- @param left string
--- @param center string
--- @param right string
--- @return string, integer, integer
local function build_aligned_line(width, left, center, right)
	if width <= 0 then
		return "", 0, 0
	end

	local center_budget = math.max(1, width - 24)
	local center_value = truncate_display(center, math.min(display_width(center), center_budget))
	local center_width = display_width(center_value)
	local center_start = math.max(1, math.floor((width - center_width) / 2) + 1)
	local center_end = math.min(width, center_start + center_width - 1)
	local left_value = truncate_display(left, math.max(0, center_start - 2))
	local right_value = truncate_display(right, math.max(0, width - center_end - 1))
	local left_width = display_width(left_value)
	local right_width = display_width(right_value)
	local left_gap = math.max(0, center_start - left_width - 1)
	local right_start = width - right_width + 1
	local right_gap = math.max(0, right_start - center_end - 1)
	local line = left_value .. string.rep(" ", left_gap) .. center_value .. string.rep(" ", right_gap) .. right_value

	return line, left_width + left_gap, center_width
end

--- Returns the configured key hint text.
--- @param value string|false|nil
--- @return string
local function key_hint(value)
	if type(value) ~= "string" or value == "" then
		return ""
	end

	return value
end

--- Builds the bottom navigation row.
--- @param width integer
--- @param previous string|nil
--- @param current string
--- @param next_title string|nil
--- @return string
local function build_navigation_line(width, previous, current, next_title)
	if width <= 0 then
		return ""
	end

	local left_text = "←  " .. sanitize_text(previous)
	local center_value = "  " .. sanitize_text(current)
	local right_text = sanitize_text(next_title) .. "  →"
	local line = build_aligned_line(width, left_text, center_value, right_text)
	return line
end

--- Builds the overlay status lines for the active session.
--- @param session table
--- @param config table
--- @param width integer
--- @return string[], table[]
function M.status_lines(session, config, width)
	local entry = session.entries[session.index]
	if not entry then
		return {}, {}
	end

	local previous = session.entries[session.index - 1]
	local next_entry = session.entries[session.index + 1]
	local summary = string.format("%d/%d  %s/%s", session.index, #session.entries, session.adapter, session.scope)
	local summary_line, summary_start, summary_width =
		build_aligned_line(width, key_hint(config.keymaps.prev), summary, key_hint(config.keymaps.next))
	local nav_line = build_navigation_line(width, previous and previous.title or nil, entry.title, next_entry and next_entry.title or nil)
	local highlights = {
		{
			line = 0,
			group = "Special",
			start_col = byte_index_from_display(summary_line, summary_start),
			end_col = byte_index_from_display(summary_line, summary_start + summary_width),
		},
	}

	return {
		summary_line,
		"",
		nav_line,
		"",
	}, highlights
end

return M
