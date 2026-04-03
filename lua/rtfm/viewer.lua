local M = {}

M.session = nil
M.augroup = vim.api.nvim_create_augroup("RtfmViewer", { clear = true })
local overlay_namespace = vim.api.nvim_create_namespace("RtfmViewerOverlay")
M.config = {
	keymaps = {
		prev = "[d",
		next = "]d",
	},
}

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

--- Centers text inside a fixed display width.
--- @param text string
--- @param width integer
--- @return string
local function center_text(text, width)
	local content = truncate_display(text, width)
	local padding = math.max(0, width - display_width(content))
	local left_padding = math.floor(padding / 2)
	local right_padding = padding - left_padding
	return string.rep(" ", left_padding) .. content .. string.rep(" ", right_padding)
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
	local line = left_value
		.. string.rep(" ", left_gap)
		.. center_value
		.. string.rep(" ", right_gap)
		.. right_value

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

--- Updates the tracked viewer window if the buffer moved.
--- @return boolean
local function resolve_window()
	if not M.session or not vim.api.nvim_buf_is_valid(M.session.bufnr) then
		return false
	end

	if M.session.winnr
		and vim.api.nvim_win_is_valid(M.session.winnr)
		and vim.api.nvim_win_get_buf(M.session.winnr) == M.session.bufnr
	then
		return true
	end

	local winnr = vim.fn.bufwinid(M.session.bufnr)
	if winnr == -1 or not vim.api.nvim_win_is_valid(winnr) then
		return false
	end

	M.session.winnr = winnr
	return true
end

--- Returns whether the current viewer session is still usable.
--- @return boolean
local function has_active_session()
	return M.session
		and vim.api.nvim_buf_is_valid(M.session.bufnr)
		and resolve_window()
		and M.session.entries[M.session.index] ~= nil
end

--- Returns the currently selected entry.
--- @return table|nil
local function current_entry()
	if not has_active_session() then
		return nil
	end

	return M.session.entries[M.session.index]
end

--- Builds the status text for the active session.
--- @param width integer
--- @return string[], table[]
local function status_lines(width)
	local entry = current_entry()
	if not entry then
		return {}, {}
	end

	local previous = M.session.entries[M.session.index - 1]
	local next_entry = M.session.entries[M.session.index + 1]
	local summary = string.format("%d/%d  %s/%s", M.session.index, #M.session.entries, M.session.adapter, M.session.scope)
	local summary_line, summary_start, summary_width = build_aligned_line(
		width,
		key_hint(M.config.keymaps.prev),
		summary,
		key_hint(M.config.keymaps.next)
	)
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

--- Applies configured navigation maps to the active viewer buffer.
--- @param bufnr integer
--- @return nil
local function apply_keymaps(bufnr)
	local prev = M.config.keymaps.prev
	local next_key = M.config.keymaps.next

	if type(prev) == "string" and prev ~= "" then
		vim.keymap.set("n", prev, M.prev, { buffer = bufnr, silent = true, desc = "RTFM previous doc" })
	end

	if type(next_key) == "string" and next_key ~= "" then
		vim.keymap.set("n", next_key, M.next, { buffer = bufnr, silent = true, desc = "RTFM next doc" })
	end
	end

--- Ensures the bottom status window exists for the current viewer window.
--- @return nil
local function render_status()
	if not has_active_session() then
		return
	end

	local width = vim.api.nvim_win_get_width(M.session.winnr)

	local overlay_buf = M.session.overlay_buf
	if not overlay_buf or not vim.api.nvim_buf_is_valid(overlay_buf) then
		overlay_buf = vim.api.nvim_create_buf(false, true)
		vim.bo[overlay_buf].bufhidden = "wipe"
		vim.bo[overlay_buf].buftype = "nofile"
		vim.bo[overlay_buf].swapfile = false
		M.session.overlay_buf = overlay_buf
	end

	local lines, highlights = status_lines(width)
	vim.bo[overlay_buf].modifiable = true
	vim.api.nvim_buf_set_lines(overlay_buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(overlay_buf, overlay_namespace, 0, -1)
	for _, highlight in ipairs(highlights) do
		vim.api.nvim_buf_add_highlight(
			overlay_buf,
			overlay_namespace,
			highlight.group,
			highlight.line,
			highlight.start_col,
			highlight.end_col
		)
	end
	vim.bo[overlay_buf].modifiable = false

	if M.session.overlay_win and vim.api.nvim_win_is_valid(M.session.overlay_win) then
		if vim.api.nvim_win_get_buf(M.session.overlay_win) ~= overlay_buf then
			vim.api.nvim_win_set_buf(M.session.overlay_win, overlay_buf)
		end
	else
		local current_win = vim.api.nvim_get_current_win()
		vim.api.nvim_set_current_win(M.session.winnr)
		vim.cmd("belowright split")
		M.session.overlay_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(M.session.overlay_win, overlay_buf)
		vim.api.nvim_set_current_win(current_win)
	end

	vim.api.nvim_win_set_height(M.session.overlay_win, #lines)
	vim.wo[M.session.overlay_win].winfixheight = true
	vim.wo[M.session.overlay_win].number = false
	vim.wo[M.session.overlay_win].relativenumber = false
	vim.wo[M.session.overlay_win].signcolumn = "no"
	vim.wo[M.session.overlay_win].foldcolumn = "0"
	vim.wo[M.session.overlay_win].spell = false
	vim.wo[M.session.overlay_win].wrap = false
	vim.wo[M.session.overlay_win].cursorline = false
	vim.wo[M.session.overlay_win].winhl = "Normal:NormalFloat"
	vim.api.nvim_buf_set_name(overlay_buf, string.format("rtfm://overlay/%s/%s", M.session.adapter, M.session.scope))
end

--- Renders an entry into the viewer buffer.
--- @param index integer
--- @return nil
local function show_entry(index)
	if not M.session or not vim.api.nvim_buf_is_valid(M.session.bufnr) or not vim.api.nvim_win_is_valid(M.session.winnr) then
		vim.notify("No active RTFM viewer session", vim.log.levels.WARN)
		return
	end

	local entry = M.session.entries[index]
	if not entry then
		vim.notify("Doc is out of range", vim.log.levels.WARN)
		return
	end

	if vim.fn.filereadable(entry.absolute_path) ~= 1 then
		vim.notify(string.format("Doc missing on disk: %s", entry.relative_path), vim.log.levels.ERROR)
		return
	end

	M.session.index = index
	local lines = vim.fn.readfile(entry.absolute_path)
	resolve_window()
	vim.api.nvim_set_current_win(M.session.winnr)
	vim.api.nvim_set_current_buf(M.session.bufnr)
	vim.bo[M.session.bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(M.session.bufnr, 0, -1, false, lines)
	vim.bo[M.session.bufnr].modifiable = false
	vim.bo[M.session.bufnr].buftype = "nofile"
	vim.bo[M.session.bufnr].bufhidden = "hide"
	vim.bo[M.session.bufnr].swapfile = false
	vim.bo[M.session.bufnr].filetype = "markdown"
	vim.bo[M.session.bufnr].modifiable = false
	vim.api.nvim_buf_set_name(M.session.bufnr, string.format("rtfm://%s/%s/%s", M.session.adapter, M.session.scope, entry.relative_path))
	vim.api.nvim_win_set_cursor(M.session.winnr, { 1, 0 })
	render_status()
end

--- Clears any status window associated with the viewer session.
--- @return nil
local function clear_overlay()
	if M.session and M.session.overlay_win and vim.api.nvim_win_is_valid(M.session.overlay_win) then
		vim.api.nvim_win_close(M.session.overlay_win, true)
	end
	if M.session and M.session.overlay_buf and vim.api.nvim_buf_is_valid(M.session.overlay_buf) then
		vim.api.nvim_buf_delete(M.session.overlay_buf, { force = true })
	end
	if M.session then
		M.session.overlay_win = nil
		M.session.overlay_buf = nil
	end
end

--- Opens an ordered documentation viewer session.
--- @param context table
--- @param entries table[]
--- @param index integer
--- @return nil
function M.open(context, entries, index)
	if M.session and vim.api.nvim_buf_is_valid(M.session.bufnr) then
		clear_overlay()
		vim.api.nvim_buf_delete(M.session.bufnr, { force = true })
	end
	vim.api.nvim_clear_autocmds({ group = M.augroup })

	local bufnr = vim.api.nvim_create_buf(false, true)
	local winnr = vim.api.nvim_get_current_win()
	M.session = {
		adapter = context.adapter,
		scope = context.scope,
		entries = entries,
		index = index,
		bufnr = bufnr,
		winnr = winnr,
		overlay_buf = nil,
		overlay_win = nil,
	}
	apply_keymaps(bufnr)

	vim.api.nvim_create_autocmd({ "WinClosed", "BufWipeout" }, {
		group = M.augroup,
		buffer = bufnr,
		once = false,
		callback = function()
			if not M.session or M.session.bufnr ~= bufnr then
				return
			end

			clear_overlay()
			M.session = nil
		end,
	})

	vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "BufEnter", "WinEnter" }, {
		group = M.augroup,
		callback = function()
			if not has_active_session() then
				return
			end

			render_status()
		end,
	})

	show_entry(index)
end

--- Updates viewer configuration.
--- @param opts table|nil
--- @return nil
function M.configure(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

--- Jumps to the next documentation entry in the current session.
--- @return nil
function M.next()
	if not has_active_session() then
		vim.notify("No active RTFM viewer session", vim.log.levels.WARN)
		return
	end

	if M.session.index >= #M.session.entries then
		vim.notify("Already at the last doc", vim.log.levels.INFO)
		return
	end

	show_entry(M.session.index + 1)
end

--- Jumps to the previous documentation entry in the current session.
--- @return nil
function M.prev()
	if not has_active_session() then
		vim.notify("No active RTFM viewer session", vim.log.levels.WARN)
		return
	end

	if M.session.index <= 1 then
		vim.notify("Already at the first doc", vim.log.levels.INFO)
		return
	end

	show_entry(M.session.index - 1)
end

return M
