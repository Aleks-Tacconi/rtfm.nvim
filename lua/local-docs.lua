local utils = require("local-docs.utils")
local cheat_sh = require("local-docs.cheat-sh")

local M = {}

M.ensure_installed = {}

--- Setup function to initialize the local documentation system
--- @param ensure_installed table: A list of documentation sources to ensure are installed
--- @return nil
M.setup = function(ensure_installed)
	M.ensure_installed = ensure_installed or M.ensure_installed
	utils.ensure_directory(utils.data_dir)

	for _, source in ipairs(M.ensure_installed) do
		cheat_sh.get_cheat_sh(source, source .. "/cheatsh/")
	end
end

return M
