local Adapter = require("rtfm.adapters.base.adapter")
local ManageView = require("rtfm.ui.manage_view")
local utils = require("rtfm.utils")

local M = {}

M.state = nil
M.state_callbacks = nil

local namespace = vim.api.nvim_create_namespace("RtfmManage")

local function has_ui()
	return #vim.api.nvim_list_uis() > 0
end

local function is_installed(name, module_path)
	local ok, adapter = pcall(function()
		return require(module_path):new()
	end)
	if not ok then
		return false
	end

	for _, scope in ipairs(Adapter.scopes_for(adapter)) do
		local index_path = scope.dir == "" and string.format("%s%s/_index.md", utils.data_dir, name)
			or string.format("%s%s/%s/_index.md", utils.data_dir, name, scope.dir)
		if vim.fn.filereadable(index_path) == 1 then
			return true
		end
	end

	return false
end
local function render()
	ManageView.render(M.state, namespace)
end

local function close()
	if not M.state then
		return
	end

	if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
		vim.api.nvim_win_close(M.state.win, true)
	end
	if M.state.buf and vim.api.nvim_buf_is_valid(M.state.buf) then
		vim.api.nvim_buf_delete(M.state.buf, { force = true })
	end
	M.state = nil
	M.state_callbacks = nil
end

local function move(step)
	if not M.state then
		return
	end

	local target = ManageView.selectable_index(M.state.items, M.state.cursor + step, step)
	if M.state.items[target] and M.state.items[target].kind == "adapter" then
		M.state.cursor = target
		render()
	end
end

local function confirm_remove(name)
	return vim.fn.confirm(string.format("Remove '%s'?", name), "&Yes\n&No", 2) == 1
end

local function act()
	if not M.state then
		return
	end

	local item = M.state.items[M.state.cursor]
	local callbacks = M.state_callbacks
	if not item or item.kind ~= "adapter" then
		return
	end

	close()
	if item.installed then
		if confirm_remove(item.name) then
			callbacks.on_remove(item.name)
		else
			callbacks.reopen()
		end
		return
	end

	callbacks.on_install(item.name)
end

--- Opens the adapter manager window.
--- @param opts table
--- @return nil
function M.open(opts)
	if not has_ui() then
		error(":RtfmManage requires an active Neovim UI")
	end

	close()
	local items = ManageView.build_items(opts.adapters, is_installed)
	local width = 54
	local height = math.max(14, math.min(#items + 5, vim.o.lines - 4))
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.max(0, math.floor((vim.o.lines - height) / 2)),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
	})

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].cursorline = false
	vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"

	M.state = {
		buf = buf,
		win = win,
		items = items,
		width = width,
		cursor = ManageView.selectable_index(items, 1, 1),
	}
	M.state_callbacks = {
		on_install = opts.on_install,
		on_remove = opts.on_remove,
		reopen = opts.reopen,
	}

	vim.keymap.set("n", "j", function()
		move(1)
	end, { buffer = buf, silent = true })
	vim.keymap.set("n", "k", function()
		move(-1)
	end, { buffer = buf, silent = true })
	vim.keymap.set("n", "<CR>", act, { buffer = buf, silent = true })
	vim.keymap.set("n", "q", close, { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true })

	render()
end

return M
