local utils = require("local-docs.utils")
local Adapter = require("local-docs.abc-adapter.adapter")

local M = {}

M.adapters = {
	python = "local-docs.adapters.python",
}

M.ensure_installed = {}

local function normalize_ensure_installed(opts)
	if type(opts) ~= "table" then
		return M.ensure_installed
	end

	if vim.islist(opts) then
		return opts
	end

	if vim.islist(opts.ensure_installed) then
		return opts.ensure_installed
	end

	return M.ensure_installed
end

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
	local module_path = M.adapters[name]
	if not module_path then
		return nil, string.format("Unknown adapter '%s'", name)
	end

	local ok, adapter_or_err = pcall(require, module_path)
	if not ok then
		return nil, string.format("Failed loading adapter '%s': %s", name, adapter_or_err)
	end

	return adapter_or_err, nil
end

function M.register_adapter(name, module_path)
	if type(name) ~= "string" or name == "" then
		error("register_adapter: name must be a non-empty string")
	end
	if type(module_path) ~= "string" or module_path == "" then
		error("register_adapter: module_path must be a non-empty string")
	end

	M.adapters[name] = module_path
end

function M.install_adapter(name)
	local adapter_module, load_err = load_adapter(name)
	if load_err then
		vim.notify(load_err, vim.log.levels.ERROR)
		return false
	end

	local adapter, instance_err = Adapter.instantiate(adapter_module)
	if instance_err then
		vim.notify(instance_err, vim.log.levels.ERROR)
		return false
	end

	for _, scope in ipairs(Adapter.SCOPES) do
		local has_scope = type(adapter.spec) == "table" and adapter.spec[scope.spec_key] ~= nil
		if has_scope and type(adapter[scope.method]) == "function" then
			local ok, err = pcall(function()
				adapter[scope.method](adapter)
			end)
			if not ok then
				vim.notify(string.format("Adapter '%s' failed on %s: %s", name, scope.spec_key, err), vim.log.levels.ERROR)
				return false
			end
		end
	end

	vim.notify(string.format("Installed '%s'", name), vim.log.levels.INFO)
	return true
end

function M.uninstall_adapter(name)
	if not M.adapters[name] then
		vim.notify(string.format("Unknown '%s'", name), vim.log.levels.ERROR)
		return false
	end

	local path = utils.data_dir .. name
	if vim.fn.isdirectory(path) == 0 then
		vim.notify(string.format("No local docs found for '%s'", name), vim.log.levels.WARN)
		return true
	end

	vim.fn.delete(path, "rf")
	vim.notify(string.format("Uninstalled '%s'", name), vim.log.levels.INFO)
	return true
end

local function create_user_commands()
	vim.api.nvim_create_user_command("LocalDocsInstall", function(opts)
		M.install_adapter(opts.args)
	end, {
		nargs = 1,
		complete = complete_adapter_name,
	})

	vim.api.nvim_create_user_command("LocalDocsUninstall", function(opts)
		M.uninstall_adapter(opts.args)
	end, {
		nargs = 1,
		complete = complete_adapter_name,
	})
end

--- Setup function to initialize the local documentation system
--- @param opts table|nil: Setup options
--- @return nil
M.setup = function(opts)
	if vim.g.local_docs_commands_created ~= 1 then
		create_user_commands()
		vim.g.local_docs_commands_created = 1
	end

	M.ensure_installed = normalize_ensure_installed(opts)

	utils.ensure_directory(utils.data_dir)

	for _, name in ipairs(M.ensure_installed) do
		M.install_adapter(name)
	end
end

return M
