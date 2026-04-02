local M = {}

M.session = nil
M.augroup = vim.api.nvim_create_augroup("RtfmViewer", { clear = true })

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

--- Builds the overlay text for the active session.
--- @return string[]
local function overlay_lines()
	local entry = current_entry()
	if not entry then
		return {}
	end

	local previous = M.session.entries[M.session.index - 1]
	local next_entry = M.session.entries[M.session.index + 1]
	return {
		string.format("%d/%d  %s/%s", M.session.index, #M.session.entries, M.session.adapter, M.session.scope),
		string.format("Prev: %s", previous and previous.title or "-"),
		string.format("Now : %s", entry.title),
		string.format("Next: %s", next_entry and next_entry.title or "-"),
	}
end

--- Ensures the floating overlay exists for the current viewer window.
--- @return nil
local function render_overlay()
	if not has_active_session() then
		return
	end

	local lines = overlay_lines()
	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end

	local overlay_buf = M.session.overlay_buf
	if not overlay_buf or not vim.api.nvim_buf_is_valid(overlay_buf) then
		overlay_buf = vim.api.nvim_create_buf(false, true)
		vim.bo[overlay_buf].bufhidden = "wipe"
		M.session.overlay_buf = overlay_buf
	end

	vim.bo[overlay_buf].modifiable = true
	vim.api.nvim_buf_set_lines(overlay_buf, 0, -1, false, lines)
	vim.bo[overlay_buf].modifiable = false

	local config = {
		relative = "win",
		win = M.session.winnr,
		row = 1,
		col = math.max(0, vim.api.nvim_win_get_width(M.session.winnr) - width - 4),
		width = math.max(width + 2, 16),
		height = #lines,
		style = "minimal",
		border = "rounded",
		focusable = false,
		zindex = 90,
	}

	if M.session.overlay_win and vim.api.nvim_win_is_valid(M.session.overlay_win) then
		vim.api.nvim_win_set_config(M.session.overlay_win, config)
	else
		M.session.overlay_win = vim.api.nvim_open_win(overlay_buf, false, config)
		vim.wo[M.session.overlay_win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"
	end
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
	render_overlay()
end

--- Clears any floating overlay associated with the viewer session.
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

			render_overlay()
		end,
	})

	show_entry(index)
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
