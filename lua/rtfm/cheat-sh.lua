local utils = require("rtfm.utils")
local M = {}

--- Downloads the list of available cheat sheet paths for the specified source and saves them locally
--- @param paths table: A list of paths to download for the specified source
--- @param source string: The source of the path e.g. go, python, etc.
--- @param dest_path string: The path to save the documentation to
local function download_list(paths, source, dest_path)
	for _, path in ipairs(paths) do
		local entry = vim.trim(path)

		if entry ~= "" and entry ~= ":list" then
			if entry:sub(-1) == "/" then
				local nested_source = source .. "/" .. entry:sub(1, -2)
				M.get_cheat_sh(nested_source, dest_path .. entry)
			else
				local doc_path = utils.data_dir .. dest_path .. entry

				utils.ensure_directory(vim.fn.fnamemodify(doc_path, ":h"))
				utils.curl("https://cheat.sh/" .. source .. "/" .. entry, doc_path)
			end
		end
	end
end

--- Pulls the cheat sheet documentation for the speicfied source and installs it locally
--- @param source string: The name of the documentation source to pull
--- @param dest_path string: The path to save the documentation to
M.get_cheat_sh = function(source, dest_path)
	local paths = utils.curl("https://cheat.sh/" .. source .. "/:list") or ""
	local paths_list = vim.fn.split(paths, "\n")
	download_list(paths_list, source, dest_path)
end

return M
