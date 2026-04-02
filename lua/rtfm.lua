local utils = require("rtfm.utils")
local Adapter = require("rtfm.abc-adapter.adapter")

local M = {}

M.adapters = {
	python = "rtfm.adapters.python",
}

M.ensure_installed = {}

local function adapter_names()
	local names = {}
	for name, _ in pairs(M.adapters) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local function complete_adapter_name(arg_lead)
	local matches = {}
	for _, name in ipairs(adapter_names()) do
		if name:find("^" .. vim.pesc(arg_lead)) then
			table.insert(matches, name)
		end
	end
	return matches
end

local function load_adapter(name)
	if not M.adapters[name] then
		error(string.format("unknown adapter '%s'", name))
	end

	return require(M.adapters[name])
end

function M.register_adapter(name, module_path)
	M.adapters[name] = module_path
end

function M.install_adapter(name)
	local ok, adapter_or_err = pcall(function()
		return load_adapter(name):new()
	end)

	if not ok then
		vim.notify(adapter_or_err, vim.log.levels.ERROR)
		return false
	end

	local adapter = adapter_or_err

	local install_ok, install_err = pcall(function()
		for _, scope in ipairs(Adapter.SCOPES) do
			if adapter.spec[scope.spec_key] then
				adapter[scope.method](adapter)
			end
		end
	end)

	if not install_ok then
		vim.notify(install_err, vim.log.levels.ERROR)
		return false
	end

	vim.notify(string.format("Installed '%s'", name), vim.log.levels.INFO)
	return true
end

function M.uninstall_adapter(name)
	local path = utils.data_dir .. name
	vim.fn.delete(path, "rf")
	vim.notify(string.format("Uninstalled '%s'", name), vim.log.levels.INFO)
	return true
end

local function create_user_commands()
	vim.api.nvim_create_user_command("RtfmInstall", function(opts)
		M.install_adapter(opts.args)
	end, {
		nargs = 1,
		complete = complete_adapter_name,
	})

	vim.api.nvim_create_user_command("RtfmUninstall", function(opts)
		M.uninstall_adapter(opts.args)
	end, {
		nargs = 1,
		complete = complete_adapter_name,
	})
end

--- Setup function to initialize the documentation system
--- @param opts table|nil: Setup options
--- @return nil
M.setup = function(opts)
	if vim.g.rtfm_commands_created ~= 1 then
		create_user_commands()
		vim.g.rtfm_commands_created = 1
	end

	M.ensure_installed = (opts and opts.ensure_installed) or {}

	utils.ensure_directory(utils.data_dir)

	for _, name in ipairs(M.ensure_installed) do
		M.install_adapter(name)
	end
end

return M
