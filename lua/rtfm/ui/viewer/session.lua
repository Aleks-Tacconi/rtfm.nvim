local M = {}

--- Updates the tracked viewer window if the buffer moved.
--- @param session table|nil
--- @return boolean
function M.resolve_window(session)
	if not session or not vim.api.nvim_buf_is_valid(session.bufnr) then
		return false
	end

	if session.winnr and vim.api.nvim_win_is_valid(session.winnr) and vim.api.nvim_win_get_buf(session.winnr) == session.bufnr then
		return true
	end

	local winnr = vim.fn.bufwinid(session.bufnr)
	if winnr == -1 or not vim.api.nvim_win_is_valid(winnr) then
		return false
	end

	session.winnr = winnr
	return true
end

--- Returns whether the current viewer session is still usable.
--- @param session table|nil
--- @return boolean
function M.has_active_session(session)
	return session and vim.api.nvim_buf_is_valid(session.bufnr) and M.resolve_window(session) and session.entries[session.index] ~= nil
end

--- Clears any status window associated with the viewer session.
--- @param session table|nil
--- @return nil
function M.clear_overlay(session)
	if session and session.overlay_win and vim.api.nvim_win_is_valid(session.overlay_win) then
		vim.api.nvim_win_close(session.overlay_win, true)
	end
	if session and session.overlay_buf and vim.api.nvim_buf_is_valid(session.overlay_buf) then
		vim.api.nvim_buf_delete(session.overlay_buf, { force = true })
	end
	if session then
		session.overlay_win = nil
		session.overlay_buf = nil
	end
end

--- Returns whether the active window is showing the viewer buffer.
--- @param session table|nil
--- @return boolean
function M.in_viewer_window(session)
	return session and vim.api.nvim_win_is_valid(0) and vim.api.nvim_win_get_buf(0) == session.bufnr
end

return M
