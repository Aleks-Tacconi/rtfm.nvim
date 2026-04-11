local M = {}

local DEFAULT_ADAPTERS = {
	go = "rtfm.adapters.go",
	lua = "rtfm.adapters.lua",
	pandas = "rtfm.adapters.pandas",
	python = "rtfm.adapters.python",
}

--- Returns the default adapter registry.
--- @return table<string, string>
function M.defaults()
	return vim.deepcopy(DEFAULT_ADAPTERS)
end

--- Registers an adapter module path.
--- @param adapters table<string, string>
--- @param name string
--- @param module_path string
--- @return nil
function M.register(adapters, name, module_path)
	adapters[name] = module_path
end

--- Loads a registered adapter module.
--- @param adapters table<string, string>
--- @param name string
--- @return table
function M.load(adapters, name)
	if not adapters[name] then
		error(string.format("unknown adapter '%s'", name))
	end

	return require(adapters[name])
end

return M
