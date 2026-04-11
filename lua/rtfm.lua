local Commands = require("rtfm.core.commands")
local Config = require("rtfm.core.config")
local Install = require("rtfm.core.install")
local Registry = require("rtfm.core.registry")
local utils = require("rtfm.utils")
local Browser = require("rtfm.browser")
local Manage = require("rtfm.manage")
local Viewer = require("rtfm.viewer")

local M = {}

M.adapters = Registry.defaults()
M._active_installs = {}
M.config = vim.deepcopy(Config.defaults)

local function load_adapter(name)
	return Registry.load(M.adapters, name)
end

function M.register_adapter(name, module_path)
	Registry.register(M.adapters, name, module_path)
end

function M.install_adapter(name, opts)
	return Install.install(name, load_adapter, M._active_installs, opts)
end

function M.uninstall_adapter(name)
	return Install.uninstall(name)
end

--- Opens the adapter manager UI.
--- @return nil
function M.manage()
	Manage.open({
		adapters = M.adapters,
		on_install = function(name)
			local ok, err = xpcall(function()
				Install.install_modal(name, load_adapter, M._active_installs)
			end, debug.traceback)
			if not ok then
				vim.notify(err, vim.log.levels.ERROR)
			end
			M.manage()
		end,
		on_remove = function(name)
			local ok, err = xpcall(function()
				Install.uninstall_modal(name)
			end, debug.traceback)
			if not ok then
				vim.notify(err, vim.log.levels.ERROR)
			end
			M.manage()
		end,
		reopen = function()
			M.manage()
		end,
	})
end

--- Opens the Telescope browser for installed docs.
--- @return boolean
function M.browse()
	local ok, err = pcall(Browser.browse, M.adapters)
	if not ok then
		vim.notify(err, vim.log.levels.ERROR)
		return false
	end

	return true
end

--- Jumps to the next doc in the active viewer.
--- @return nil
function M.next_doc()
	Viewer.next()
end

--- Jumps to the previous doc in the active viewer.
--- @return nil
function M.prev_doc()
	Viewer.prev()
end

--- Setup function to initialize the documentation system
--- @param opts table|nil: Setup options
--- @return nil
M.setup = function(opts)
	M.config = Config.merge(M.config, opts)
	Viewer.configure(M.config.viewer)
	Commands.apply_global_keymaps(M.config, {
		manage = M.manage,
		browse = M.browse,
	})

	if vim.g.rtfm_commands_created ~= 1 then
		Commands.create_user_commands({
			manage = M.manage,
			browse = M.browse,
			next_doc = M.next_doc,
			prev_doc = M.prev_doc,
		})
		vim.g.rtfm_commands_created = 1
	end

	utils.ensure_directory(utils.data_dir)
end

return M
