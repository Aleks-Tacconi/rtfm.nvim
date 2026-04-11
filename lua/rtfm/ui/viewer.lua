local Render = require("rtfm.ui.viewer.render")
local Session = require("rtfm.ui.viewer.session")

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

--- Opens an ordered documentation viewer session.
--- @param context table
--- @param entries table[]
--- @param index integer
--- @return nil
function M.open(context, entries, index)
	if M.session and vim.api.nvim_buf_is_valid(M.session.bufnr) then
		Session.clear_overlay(M.session)
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
	Render.apply_keymaps(bufnr, M.config, {
		next = M.next,
		prev = M.prev,
	})

	vim.api.nvim_create_autocmd("BufWipeout", {
		group = M.augroup,
		buffer = bufnr,
		once = false,
		callback = function()
			if not M.session or M.session.bufnr ~= bufnr then
				return
			end

			Session.clear_overlay(M.session)
			M.session = nil
		end,
	})

	vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "BufEnter", "WinEnter" }, {
		group = M.augroup,
		callback = function()
			if not Session.has_active_session(M.session) or not Session.in_viewer_window(M.session) then
				return
			end

			Render.render_status(M.session, M.config, overlay_namespace)
		end,
	})

	Render.show_entry(M.session, index, M.config, overlay_namespace)
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
	if not Session.has_active_session(M.session) then
		vim.notify("No active RTFM viewer session", vim.log.levels.WARN)
		return
	end

	if M.session.index >= #M.session.entries then
		vim.notify("Already at the last doc", vim.log.levels.INFO)
		return
	end

	Render.show_entry(M.session, M.session.index + 1, M.config, overlay_namespace)
end

--- Jumps to the previous documentation entry in the current session.
--- @return nil
function M.prev()
	if not Session.has_active_session(M.session) then
		vim.notify("No active RTFM viewer session", vim.log.levels.WARN)
		return
	end

	if M.session.index <= 1 then
		vim.notify("Already at the first doc", vim.log.levels.INFO)
		return
	end

	Render.show_entry(M.session, M.session.index - 1, M.config, overlay_namespace)
end

return M
