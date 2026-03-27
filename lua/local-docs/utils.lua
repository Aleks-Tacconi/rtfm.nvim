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

return M
