local M = {}

--- Returns the display width for text.
--- @param text string
--- @return integer
local function display_width(text)
	return vim.fn.strdisplaywidth(text)
end

--- Centers text to the target width.
--- @param text string
--- @param width integer
--- @return string
local function center_text(text, width)
	local padding = math.max(0, width - display_width(text))
	local left = math.floor(padding / 2)
	local right = padding - left
	return string.rep(" ", left) .. text .. string.rep(" ", right)
end

--- Builds visible manager items from the adapter registry.
--- @param adapters table<string, string>
--- @param is_installed fun(name: string, module_path: string): boolean
--- @return table[]
function M.build_items(adapters, is_installed)
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

--- Finds the next selectable adapter row.
--- @param items table[]
--- @param start integer
--- @param step integer
--- @return integer
function M.selectable_index(items, start, step)
	local index = start
	while index >= 1 and index <= #items do
		if items[index].kind == "adapter" then
			return index
		end
		index = index + step
	end

	return start
end

--- Renders the manager buffer.
--- @param state table|nil
--- @param namespace integer
--- @return nil
function M.render(state, namespace)
	if not state then
		return
	end

	local lines = {
		center_text("󰆍  RTFM Manager", state.width),
		center_text("  j/k move   <CR> select   q close", state.width),
		"",
	}
	for _, item in ipairs(state.items) do
		table.insert(lines, item.label)
	end

	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(state.buf, namespace, 0, -1)
	vim.bo[state.buf].modifiable = false

	for index, item in ipairs(state.items) do
		if item.kind == "section" then
			vim.api.nvim_buf_add_highlight(state.buf, namespace, "Title", index + 2, 0, -1)
		end
	end

	vim.api.nvim_buf_add_highlight(state.buf, namespace, "FloatTitle", 0, 0, -1)
	vim.api.nvim_buf_add_highlight(state.buf, namespace, "Comment", 1, 0, -1)
	vim.api.nvim_win_set_cursor(state.win, { state.cursor + 3, 0 })
end

return M
