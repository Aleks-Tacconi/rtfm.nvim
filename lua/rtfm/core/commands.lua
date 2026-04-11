local M = {}

--- Applies configured global keymaps.
--- @param config table
--- @param handlers table
--- @return nil
function M.apply_global_keymaps(config, handlers)
	local manage = config.keymaps.manage
	local browse = config.keymaps.browse

	if type(manage) == "string" and manage ~= "" then
		vim.keymap.set("n", manage, handlers.manage, { silent = true, desc = "RTFM manage adapters" })
	end

	if type(browse) == "string" and browse ~= "" then
		vim.keymap.set("n", browse, handlers.browse, { silent = true, desc = "RTFM browse docs" })
	end
end

--- Creates the public user commands once per session.
--- @param handlers table
--- @return nil
function M.create_user_commands(handlers)
	vim.api.nvim_create_user_command("RtfmManage", handlers.manage, { nargs = 0 })
	vim.api.nvim_create_user_command("RtfmBrowse", handlers.browse, { nargs = 0 })
	vim.api.nvim_create_user_command("RtfmDocNext", handlers.next_doc, { nargs = 0 })
	vim.api.nvim_create_user_command("RtfmDocPrev", handlers.prev_doc, { nargs = 0 })
end

return M
