local M = {}

M.data_dir = vim.fn.stdpath("data") .. "/local-docs/"

--- CURL wrapper function to fetch a URL. Returns the fetched content as a string.
--- If save_file is provided, it saves the content to the specified file path instead.
--- @param url string: The full URL to fetch
--- @param save_file string|nil: Optional file path to save the fetched content
--- @return string|nil: The fetched content if save_file is nil, otherwise nil
M.curl = function(url, save_file)
	local output = vim.fn.system({
		"curl",
		"-fsSL",
		url,
	})

	if vim.v.shell_error ~= 0 then
		return nil
	end

	if save_file then
		vim.fn.writefile(vim.split(output, "\n"), save_file)
		return nil
	else
		return output
	end
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

local function normalize_markdown(md)
	local lines = vim.split(md, "\n", { plain = true, trimempty = false })
	local in_code_block = false

	for i, line in ipairs(lines) do
		if line:match("^```") then
			if line == "``` highlight" then
				lines[i] = "```text"
			end
			in_code_block = not in_code_block
		elseif not in_code_block then
			if line:match("^%s*%[[^%]]-%]:%s*.-$") or line:match("^%s*$") then
				lines[i] = ""
			else
			line = line:gsub("%[¶%]%([^\n]-%)", "")
			line = line:gsub("%[([^%[%]]-)%]%([^\n]-%)", "%1")
			line = line:gsub("%[([^%[%]]-)%]%[[^%]]-%]", "%1")
			line = line:gsub("%[([^%[%]]-)%]", "%1")
			line = line:gsub("¶", "")

			local previous = nil
			while line ~= previous do
				previous = line
				line = line:gsub("`([^`\n]-)``%s*``([^`\n]-)`", "`%1 %2`")
			end

			if line:match("^%s*$") then
				lines[i] = ""
			else
				lines[i] = line
			end
			end
		elseif line == "``` highlight" then
			lines[i] = "```text"
		end
	end

	local normalized = table.concat(lines, "\n")
	normalized = normalized:gsub("\n\n\n+", "\n\n")
	return vim.trim(normalized) .. "\n"
end

--- Converts HTML to Markdown using pandoc.
--- @param html string
--- @return string
M.html_to_markdown = function(html)
	local output = vim.fn.system({
		"pandoc",
		"-f",
		"html",
		"-t",
		"gfm-raw_html",
		"--reference-links",
		"--wrap=auto",
		"--columns=100",
		"--quiet",
	}, html)

	if vim.v.shell_error ~= 0 then
		error("pandoc failed converting html to markdown")
	end

	return normalize_markdown(output)
end

return M
