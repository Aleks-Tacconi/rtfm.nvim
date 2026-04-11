local Layout = require("rtfm.ui.viewer.layout")
local Session = require("rtfm.ui.viewer.session")

local M = {}

--- Applies configured navigation maps to the active viewer buffer.
--- @param bufnr integer
--- @param config table
--- @param handlers table
--- @return nil
function M.apply_keymaps(bufnr, config, handlers)
	local prev = config.keymaps.prev
	local next_key = config.keymaps.next

	if type(prev) == "string" and prev ~= "" then
		vim.keymap.set("n", prev, handlers.prev, { buffer = bufnr, silent = true, desc = "RTFM previous doc" })
	end

	if type(next_key) == "string" and next_key ~= "" then
		vim.keymap.set("n", next_key, handlers.next, { buffer = bufnr, silent = true, desc = "RTFM next doc" })
	end
end

--- Renders the viewer status overlay.
--- @param session table|nil
--- @param config table
--- @param overlay_namespace integer
--- @return nil
function M.render_status(session, config, overlay_namespace)
	if not Session.has_active_session(session) then
		return
	end

	local width = vim.api.nvim_win_get_width(session.winnr)
	local overlay_buf = session.overlay_buf
	if not overlay_buf or not vim.api.nvim_buf_is_valid(overlay_buf) then
		overlay_buf = vim.api.nvim_create_buf(false, true)
		vim.bo[overlay_buf].bufhidden = "wipe"
		vim.bo[overlay_buf].buftype = "nofile"
		vim.bo[overlay_buf].swapfile = false
		session.overlay_buf = overlay_buf
	end

	local lines, highlights = Layout.status_lines(session, config, width)
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

	if session.overlay_win and vim.api.nvim_win_is_valid(session.overlay_win) then
		if vim.api.nvim_win_get_buf(session.overlay_win) ~= overlay_buf then
			vim.api.nvim_win_set_buf(session.overlay_win, overlay_buf)
		end
	else
		local current_win = vim.api.nvim_get_current_win()
		vim.api.nvim_set_current_win(session.winnr)
		vim.cmd("belowright split")
		session.overlay_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(session.overlay_win, overlay_buf)
		vim.api.nvim_set_current_win(current_win)
	end

	vim.api.nvim_win_set_height(session.overlay_win, #lines)
	vim.wo[session.overlay_win].winfixheight = true
	vim.wo[session.overlay_win].number = false
	vim.wo[session.overlay_win].relativenumber = false
	vim.wo[session.overlay_win].signcolumn = "no"
	vim.wo[session.overlay_win].foldcolumn = "0"
	vim.wo[session.overlay_win].spell = false
	vim.wo[session.overlay_win].wrap = false
	vim.wo[session.overlay_win].cursorline = false
	vim.wo[session.overlay_win].winhl = "Normal:NormalFloat"
	vim.api.nvim_buf_set_name(overlay_buf, string.format("rtfm://overlay/%s/%s", session.adapter, session.scope))
end

--- Renders an entry into the viewer buffer.
--- @param session table|nil
--- @param index integer
--- @param config table
--- @param overlay_namespace integer
--- @return nil
function M.show_entry(session, index, config, overlay_namespace)
	if not session or not vim.api.nvim_buf_is_valid(session.bufnr) or not vim.api.nvim_win_is_valid(session.winnr) then
		vim.notify("No active RTFM viewer session", vim.log.levels.WARN)
		return
	end

	local entry = session.entries[index]
	if not entry then
		vim.notify("Doc is out of range", vim.log.levels.WARN)
		return
	end

	if vim.fn.filereadable(entry.absolute_path) ~= 1 then
		vim.notify(string.format("Doc missing on disk: %s", entry.relative_path), vim.log.levels.ERROR)
		return
	end

	session.index = index
	local lines = vim.fn.readfile(entry.absolute_path)
	Session.resolve_window(session)
	vim.api.nvim_set_current_win(session.winnr)
	vim.api.nvim_set_current_buf(session.bufnr)
	vim.bo[session.bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(session.bufnr, 0, -1, false, lines)
	vim.bo[session.bufnr].modifiable = false
	vim.bo[session.bufnr].buftype = "nofile"
	vim.bo[session.bufnr].bufhidden = "wipe"
	vim.bo[session.bufnr].swapfile = false
	vim.bo[session.bufnr].filetype = "markdown"
	vim.bo[session.bufnr].modifiable = false
	vim.api.nvim_buf_set_name(
		session.bufnr,
		string.format("rtfm://%s/%s/%s", session.adapter, session.scope, entry.relative_path)
	)
	vim.api.nvim_win_set_cursor(session.winnr, { 1, 0 })
	M.render_status(session, config, overlay_namespace)
end

return M
