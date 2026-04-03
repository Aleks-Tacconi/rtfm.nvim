local M = {}

M.state = nil

local namespace = vim.api.nvim_create_namespace("RtfmProgress")

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

local function center_config(width, height)
	local columns = vim.o.columns
	local lines = vim.o.lines - vim.o.cmdheight
	return {
		relative = "editor",
		row = math.max(0, math.floor((lines - height) / 2)),
		col = math.max(0, math.floor((columns - width) / 2)),
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		zindex = 95,
	}
end

local function ensure_window(height)
	if not M.state or not has_ui() then
		return
	end

	local config = center_config(M.state.width, height)
	if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
		vim.api.nvim_win_set_config(M.state.win, config)
		vim.api.nvim_win_set_height(M.state.win, height)
		return
	end

	M.state.win = vim.api.nvim_open_win(M.state.buf, true, config)
	vim.wo[M.state.win].number = false
	vim.wo[M.state.win].relativenumber = false
	vim.wo[M.state.win].signcolumn = "no"
	vim.wo[M.state.win].foldcolumn = "0"
	vim.wo[M.state.win].spell = false
	vim.wo[M.state.win].wrap = false
	vim.wo[M.state.win].cursorline = false
	vim.wo[M.state.win].winfixwidth = true
	vim.wo[M.state.win].winfixheight = true
	vim.wo[M.state.win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"
end

local function render()
	if not M.state then
		return
	end

	local lines = { center_text(M.state.title, M.state.width), "" }
	for _, line in ipairs(M.state.lines) do
		table.insert(lines, line)
	end

	if not has_ui() then
		return
	end

	ensure_window(#lines)
	vim.bo[M.state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(M.state.buf, namespace, 0, -1)
	vim.api.nvim_buf_add_highlight(M.state.buf, namespace, "FloatTitle", 0, 0, -1)
	for index = 3, #lines do
		local line = lines[index]
		if line:find("running", 1, true) then
			vim.api.nvim_buf_add_highlight(M.state.buf, namespace, "DiagnosticWarn", index - 1, 0, -1)
		elseif line:find("done", 1, true) then
			vim.api.nvim_buf_add_highlight(M.state.buf, namespace, "DiagnosticOk", index - 1, 0, -1)
		elseif line:find("pending", 1, true) then
			vim.api.nvim_buf_add_highlight(M.state.buf, namespace, "Comment", index - 1, 0, -1)
		end
	end
	vim.bo[M.state.buf].modifiable = false
	vim.cmd("redraw")
end

--- Opens a modal progress window.
--- @param title string
--- @return nil
function M.open(title)
	M.close()
	M.state = {
		title = title,
		lines = {},
		buf = nil,
		win = nil,
		width = 68,
	}

	if has_ui() then
		M.state.buf = vim.api.nvim_create_buf(false, true)
		vim.bo[M.state.buf].buftype = "nofile"
		vim.bo[M.state.buf].bufhidden = "wipe"
		vim.bo[M.state.buf].swapfile = false
		vim.bo[M.state.buf].modifiable = false
	end

	render()
end

--- Replaces progress content lines.
--- @param lines string[]
--- @return nil
function M.set_lines(lines)
	if not M.state then
		return
	end

	M.state.lines = vim.deepcopy(lines)
	render()
end

--- Closes the progress window.
--- @return nil
function M.close()
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
end

return M
