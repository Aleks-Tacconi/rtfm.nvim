local Adapter = require("rtfm.adapters.base.adapter")
local utils = require("rtfm.utils")

local M = {}

M.state = nil
M.state_callbacks = nil

local namespace = vim.api.nvim_create_namespace("RtfmManage")

local function has_ui()
	return #vim.api.nvim_list_uis() > 0
end

local function display_width(text)
	return vim.fn.strdisplaywidth(text)
end

local function center_text(text, width)
	local padding = math.max(0, width - display_width(text))
	local left = math.floor(padding / 2)
	local right = padding - left
	return string.rep(" ", left) .. text .. string.rep(" ", right)
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

local function build_items(adapters)
	local installed = {}
	local pending = {}

	for name, module_path in pairs(adapters or {}) do
		local target = is_installed(name, module_path) and installed or pending
		table.insert(target, name)
	end

	table.sort(installed)
	table.sort(pending)

	local items = {
		{ kind = "section", label = string.format(" 󰄬 Installed (%d)", #installed) },
		{ kind = "blank", label = "" },
	}
	for _, name in ipairs(installed) do
		table.insert(items, { kind = "adapter", name = name, installed = true, label = string.format(" %s", name) })
	end

	table.insert(items, { kind = "blank", label = "" })
	table.insert(items, { kind = "section", label = string.format(" 󰏖 Available (%d)", #pending) })
	table.insert(items, { kind = "blank", label = "" })
	for _, name in ipairs(pending) do
		table.insert(items, { kind = "adapter", name = name, installed = false, label = string.format(" %s", name) })
	end

	return items
end

local function selectable_index(items, start, step)
	local index = start
	while index >= 1 and index <= #items do
		if items[index].kind == "adapter" then
			return index
		end
		index = index + step
	end

	return start
end

local function render()
	if not M.state then
		return
	end

	local lines = {
		center_text("󰆍  RTFM Manager", M.state.width),
		center_text("  j/k move   <CR> select   q close", M.state.width),
		"",
	}
	for _, item in ipairs(M.state.items) do
		table.insert(lines, item.label)
	end

	vim.bo[M.state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(M.state.buf, namespace, 0, -1)
	vim.bo[M.state.buf].modifiable = false

	for index, item in ipairs(M.state.items) do
		local line = index + 3
		if item.kind == "section" then
			vim.api.nvim_buf_add_highlight(M.state.buf, namespace, "Title", line - 1, 0, -1)
		end
	end

	vim.api.nvim_buf_add_highlight(M.state.buf, namespace, "FloatTitle", 0, 0, -1)
	vim.api.nvim_buf_add_highlight(M.state.buf, namespace, "Comment", 1, 0, -1)

	vim.api.nvim_win_set_cursor(M.state.win, { M.state.cursor + 3, 0 })
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

	local target = selectable_index(M.state.items, M.state.cursor + step, step)
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
	local items = build_items(opts.adapters)
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
		cursor = selectable_index(items, 1, 1),
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
