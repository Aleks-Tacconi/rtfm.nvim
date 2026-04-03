local M = {}

M.data_dir = vim.fn.stdpath("data") .. "/rtfm/"

local CURL_BASE_ARGS = {
	"curl",
	"-fsSL",
	"--retry",
	"4",
	"--retry-delay",
	"1",
	"--retry-all-errors",
	"--connect-timeout",
	"10",
	"--max-time",
	"60",
	"-A",
	"Mozilla/5.0 (compatible; rtfm.nvim)",
}

local function curl_command(url)
	local cmd = vim.deepcopy(CURL_BASE_ARGS)
	table.insert(cmd, url)
	return cmd
end

local function shell_error_message(prefix, result)
	local stderr = vim.trim(result.stderr or "")
	if stderr == "" then
		return string.format("%s failed with exit code %d", prefix, result.code or -1)
	end

	return string.format("%s failed: %s", prefix, stderr)
end

--- CURL wrapper function to fetch a URL. Returns the fetched content as a string.
--- If save_file is provided, it saves the content to the specified file path instead.
--- @param url string: The full URL to fetch
--- @param save_file string|nil: Optional file path to save the fetched content
--- @return string|nil: The fetched content if save_file is nil, otherwise nil
M.curl = function(url, save_file)
	local result = vim.system(curl_command(url), { text = true }):wait(70000)

	if result.code ~= 0 then
		return nil
	end

	local output = result.stdout or ""

	if save_file then
		vim.fn.writefile(vim.split(output, "\n"), save_file)
		return nil
	else
		return output
	end
end

--- Fetches a URL without blocking the Neovim UI.
--- @param url string
--- @param callback fun(ok: boolean, result: string)
M.curl_async = function(url, callback)
	vim.system(curl_command(url), { text = true }, vim.schedule_wrap(function(result)
		if result.code ~= 0 then
			callback(false, shell_error_message(string.format("curl %s", url), result))
			return
		end

		callback(true, result.stdout or "")
	end))
end

--- Ensures that the specified directory exists. If it does not exist, it creates the directory.
--- @param path string: The directory path to ensure exists
M.ensure_directory = function(path)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
	end
end

--- Writes string content to a file, creating parent directories if needed.
--- @param path string: The file path to write content to
--- @param content string: The file content
M.write_file = function(path, content)
	M.ensure_directory(vim.fn.fnamemodify(path, ":h"))
	vim.fn.writefile(vim.split(content or "", "\n", { plain = true, trimempty = false }), path)
end

--- Deletes a path and reports whether it succeeded.
--- @param path string
--- @return boolean, string|nil
M.safe_delete = function(path)
	local ok, result = pcall(vim.fn.delete, path, "rf")
	if not ok then
		return false, result
	end

	if result ~= 0 then
		return false, string.format("could not delete '%s'", path)
	end

	return true, nil
end

--- Renames a path and reports whether it succeeded.
--- @param from string
--- @param to string
--- @return boolean, string|nil
M.safe_rename = function(from, to)
	local ok, result, err_name = pcall(vim.uv.fs_rename, from, to)
	if not ok then
		return false, result
	end

	if result then
		return true, nil
	end

	return false, err_name or string.format("could not rename '%s' to '%s'", from, to)
end

--- Creates a temporary directory under a parent path.
--- @param parent string
--- @param prefix string
--- @return string|nil, string|nil
M.make_temp_dir = function(parent, prefix)
	M.ensure_directory(parent)

	local temp_name = string.format(".%s-%d-%d", prefix, vim.fn.getpid(), vim.uv.hrtime())
	local temp_path = parent .. "/" .. temp_name
	local ok, err = pcall(vim.fn.mkdir, temp_path, "p")
	if not ok then
		return nil, err
	end

	return temp_path, nil
end

local function normalize_markdown(md)
	local previous = nil
	while md ~= previous do
		previous = md
		md = md:gsub("`([^`\n]-)``%s*``([^`\n]-)`", "`%1 %2`")
	end

	local lines = vim.split(md, "\n", { plain = true, trimempty = false })
	local in_code_block = false

	for i, line in ipairs(lines) do
		if line:match("^```") then
			if line == "``` highlight" then
				lines[i] = "```text"
			end
			in_code_block = not in_code_block
		elseif not in_code_block then
			if line:match("^%s*%[[^%]]-%]:%s*[^\n]*$") or line:match("^%s*$") then
				lines[i] = ""
			else
				line = line:gsub("%[¶%]%[[^%]]-%]", "")
				line = line:gsub("%[¶%]%([^\n]-%)", "")
				line = line:gsub("%[([^%[%]]-)%]%([^\n]-%)", "%1")
				line = line:gsub("%[([^%[%]]-)%]%[[^%]]-%]", "%1")
				line = line:gsub("%[(`[^%]]-`)%]", "%1")
				line = line:gsub("%[([%*`%a][^%[%]]-)%]", "%1")
				line = line:gsub("%[%]", "")
				line = line:gsub("\\%[%[%d+%]\\%]", "")
				line = line:gsub("&nbsp;", "")
				line = line:gsub("¶", "")
				lines[i] = line
			end
		end
	end

	local normalized = table.concat(lines, "\n")
	previous = nil
	while normalized ~= previous do
		previous = normalized
		normalized = normalized:gsub("%[(.-)\n%s*(.-)%]%(([^)\n]-)%)", "%1 %2")
		normalized = normalized:gsub("%[(.-)\n%s*(.-)%]%[([^%]\n]-)%]", "%1 %2")
		normalized = normalized:gsub("%[([^%]\n]-)\n%s*([^%]\n]-)%]", "%1 %2")
	end
	normalized = normalized:gsub("%[%]", "")
	normalized = normalized:gsub("\n([%-*+] [^\n]+)\n\n([%-*+] )", "\n%1\n%2")
	normalized = normalized:gsub("\n\n\n+", "\n\n")
	return vim.trim(normalized) .. "\n"
end

--- Converts HTML to Markdown using pandoc.
--- @param html string
--- @return string
M.html_to_markdown = function(html)
	local result = vim.system({
		"pandoc",
		"-f",
		"html",
		"-t",
		"gfm-raw_html",
		"--reference-links",
		"--wrap=auto",
		"--columns=100",
		"--quiet",
	}, { text = true, stdin = html }):wait(120000)

	if result.code ~= 0 then
		error("pandoc failed converting html to markdown")
	end

	return normalize_markdown(result.stdout or "")
end

--- Converts HTML to Markdown without blocking the Neovim UI.
--- @param html string
--- @param callback fun(ok: boolean, result: string)
M.html_to_markdown_async = function(html, callback)
	vim.system({
		"pandoc",
		"-f",
		"html",
		"-t",
		"gfm-raw_html",
		"--reference-links",
		"--wrap=auto",
		"--columns=100",
		"--quiet",
	}, { text = true, stdin = html }, vim.schedule_wrap(function(result)
		if result.code ~= 0 then
			callback(false, shell_error_message("pandoc html conversion", result))
			return
		end

		callback(true, normalize_markdown(result.stdout or ""))
	end))
end

return M
