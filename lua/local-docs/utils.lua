local M = {}

M.data_dir = vim.fn.stdpath("data") .. "/local-docs/"

--- CURL wrapper function to fetch resources. Returns the content of the fetched resource as a string.
--- If save_file is provided, it saves the content to the specified file path instead of returning it.
--- @param domain string: The domain to fetch from (e.g., "cheat.sh")
--- @param resource string: The resource path to fetch (e.g., "lua/:list")
--- @param save_file string|nil: Optional file path to save the fetched content. If nil,
---                              the content is returned as a string.
--- @return string|nil: The content of the fetched resource as a string if save_file is nil, otherwise nil.
M.curl = function(domain, resource, save_file)
	local output = vim.fn.system({
		"curl",
		"-fsSL",
		domain .. resource,
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

--- Ensures that the specified URL has a valid format (i.e., starts with "http://" or "https://").
--- If the URL does not have a valid format, it displays an error message using vim.notify. and returns false.
--- If the URL is valid, it returns true.
--- @param url string: The URL to check
--- @param error_message string: The error message to display if the URL does not have a valid format
M.ensure_url_format = function(url, error_message)
	if not url:match("^https?://") then
		vim.notify(error_message, vim.log.levels.ERROR)
		return false
	end
	return true
end

return M
