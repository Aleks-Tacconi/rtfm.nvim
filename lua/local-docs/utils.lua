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

return M
