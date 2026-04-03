local utils = require("rtfm.utils")
local Adapter = require("rtfm.abc-adapter.adapter")
local Browser = require("rtfm.browser")
local Manage = require("rtfm.manage")
local Progress = require("rtfm.progress")
local Viewer = require("rtfm.viewer")

local M = {}

M.adapters = {
	go = "rtfm.adapters.go",
	lua = "rtfm.adapters.lua",
	pandas = "rtfm.adapters.pandas",
	python = "rtfm.adapters.python",
}

M._active_installs = {}
M.config = {
	keymaps = {
		manage = "<leader>rm",
		browse = "<leader>rb",
	},
	viewer = {
		keymaps = {
			prev = "[d",
			next = "]d",
		},
	},
}

local function load_adapter(name)
	if not M.adapters[name] then
		error(string.format("unknown adapter '%s'", name))
	end

	return require(M.adapters[name])
end

local function notify(message, level, should_notify, opts)
	if should_notify == false then
		return
	end

	return vim.notify(message, level, opts or {})
end

local function scope_lock_key(adapter, scope)
	local key = scope.dir ~= "" and scope.dir or scope.spec_key
	return string.format("%s:%s", adapter.doc, key)
end

local function acquire_scope_locks(adapter)
	local keys = {}

	for _, scope in ipairs(Adapter.scopes_for(adapter)) do
		local key = scope_lock_key(adapter, scope)
		if M._active_installs[key] then
			return nil, string.format("Install already running for '%s' %s", adapter.doc, scope.label or scope.dir)
		end

		table.insert(keys, key)
	end

	for _, key in ipairs(keys) do
		M._active_installs[key] = true
	end

	return keys, nil
end

local function release_scope_locks(keys)
	for _, key in ipairs(keys or {}) do
		M._active_installs[key] = nil
	end
end

local function enabled_scopes(adapter)
	return Adapter.scopes_for(adapter)
end

local function run_scopes_sync(adapter, scopes, on_scope, on_source)
	for index, scope in ipairs(scopes) do
		if on_scope then
			on_scope(scope, index, #scopes)
		end

		adapter[scope.method .. "_sync"](adapter, {
			on_source = function(source, source_index, source_total)
				if on_source then
					on_source(scope, index, #scopes, source, source_index, source_total)
				end
			end,
		})
	end
end

local function run_scopes(adapter, scopes, opts, done)
	local index = 1

	local function step()
		local scope = scopes[index]
		if not scope then
			done(true)
			return
		end

		notify(
			string.format("Installing '%s' %s (%d/%d)", adapter.doc, scope.label or scope.dir, index, #scopes),
			vim.log.levels.INFO,
			opts.notify
		)
		adapter[scope.method](adapter, function(ok, err)
			if not ok then
				done(false, err)
				return
			end

			index = index + 1
			vim.schedule(step)
		end)
	end

	vim.schedule(step)
end

function M.register_adapter(name, module_path)
	M.adapters[name] = module_path
end

local function progress_lines(_, scopes, active_index, active_status, detail)
	local lines = {}

	for index, scope in ipairs(scopes) do
		local label = scope.label or scope.dir
		local icon = "󰄱"
		local status = "pending"
		if index < active_index then
			icon = "󰄬"
			status = "done"
		elseif index == active_index then
			icon = active_status == "running" and "󰑓" or "󰄱"
			status = active_status
		end

		table.insert(lines, string.format(" %s  %-8s  %s", icon, status, label))
	end

	if detail and detail ~= "" then
		table.insert(lines, "")
		table.insert(lines, "   " .. detail)
	end

	return lines
end

local function install_adapter_modal(name)
	local adapter = load_adapter(name):new()
	local locks, lock_err = acquire_scope_locks(adapter)
	if not locks then
		error(lock_err)
	end

	local scopes = enabled_scopes(adapter)
	local detail = nil
	Progress.open(string.format(" 󰇚  Installing %s", name))
	Progress.set_lines(progress_lines(name, scopes, 1, "running", detail))

	local ok, err = xpcall(function()
		run_scopes_sync(adapter, scopes, function(_, index)
			detail = nil
			Progress.set_lines(progress_lines(name, scopes, index, "running", detail))
		end, function(_, index, _, source, source_index, source_total)
			detail = string.format("source %d/%d  %s", source_index, source_total, source)
			Progress.set_lines(progress_lines(name, scopes, index, "running", detail))
		end)
	end, debug.traceback)

	if ok then
		Progress.set_lines(progress_lines(name, scopes, #scopes + 1, "done", nil))
	end

	Progress.close()
	release_scope_locks(locks)

	if not ok then
		error(err)
	end

	vim.notify(string.format("Installed '%s'", name), vim.log.levels.INFO)
end

local function uninstall_adapter_modal(name)
	Progress.open(string.format("Removing %s", name))
	Progress.set_lines({ string.format(" 󰆴  Removing adapter  %s", name) })
	local ok, err = utils.safe_delete(utils.data_dir .. name)
	Progress.close()
	if not ok then
		error(err)
	end

	vim.notify(string.format("Removed '%s'", name), vim.log.levels.INFO)
end

function M.install_adapter(name, opts)
	opts = opts or {}
	local notify_enabled = opts.notify ~= false
	local ok, adapter_or_err = pcall(function()
		return load_adapter(name):new()
	end)

	if not ok then
		notify(adapter_or_err, vim.log.levels.ERROR, notify_enabled)
		if opts.on_done then
			opts.on_done(false, adapter_or_err)
		end
		return false
	end

	local adapter = adapter_or_err
	local locks, lock_err = acquire_scope_locks(adapter)
	if not locks then
		notify(lock_err, vim.log.levels.WARN, notify_enabled)
		if opts.on_done then
			opts.on_done(false, lock_err)
		end
		return false
	end

	notify(string.format("Installing '%s' in background...", name), vim.log.levels.INFO, notify_enabled)

	run_scopes(adapter, enabled_scopes(adapter), { notify = notify_enabled }, function(install_ok, install_err)
		release_scope_locks(locks)

		if not install_ok then
			notify(install_err, vim.log.levels.ERROR, notify_enabled)
			if opts.on_done then
				opts.on_done(false, install_err)
			end
			return
		end

		notify(string.format("Installed '%s'", name), vim.log.levels.INFO, notify_enabled)
		if opts.on_done then
			opts.on_done(true)
		end
	end)

	return true
end

function M.uninstall_adapter(name)
	local path = utils.data_dir .. name
	vim.fn.delete(path, "rf")
	vim.notify(string.format("Uninstalled '%s'", name), vim.log.levels.INFO)
	return true
end

--- Opens the adapter manager UI.
--- @return nil
function M.manage()
	Manage.open({
		adapters = M.adapters,
		on_install = function(name)
			local ok, err = xpcall(function()
				install_adapter_modal(name)
			end, debug.traceback)
			if not ok then
				vim.notify(err, vim.log.levels.ERROR)
			end
			M.manage()
		end,
		on_remove = function(name)
			local ok, err = xpcall(function()
				uninstall_adapter_modal(name)
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

--- Applies configured global keymaps.
--- @return nil
local function apply_global_keymaps()
	local manage = M.config.keymaps.manage
	local browse = M.config.keymaps.browse

	if type(manage) == "string" and manage ~= "" then
		vim.keymap.set("n", manage, M.manage, { silent = true, desc = "RTFM manage adapters" })
	end

	if type(browse) == "string" and browse ~= "" then
		vim.keymap.set("n", browse, M.browse, { silent = true, desc = "RTFM browse docs" })
	end
end

local function create_user_commands()
	vim.api.nvim_create_user_command("RtfmManage", function()
		M.manage()
	end, {
		nargs = 0,
	})

	vim.api.nvim_create_user_command("RtfmBrowse", function()
		M.browse()
	end, {
		nargs = 0,
	})

	vim.api.nvim_create_user_command("RtfmDocNext", function()
		M.next_doc()
	end, {
		nargs = 0,
	})

	vim.api.nvim_create_user_command("RtfmDocPrev", function()
		M.prev_doc()
	end, {
		nargs = 0,
	})
end

--- Setup function to initialize the documentation system
--- @param opts table|nil: Setup options
--- @return nil
M.setup = function(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", M.config, {
		keymaps = opts.keymaps or {},
		viewer = opts.viewer or {},
	})
	Viewer.configure(M.config.viewer)
	apply_global_keymaps()

	if vim.g.rtfm_commands_created ~= 1 then
		create_user_commands()
		vim.g.rtfm_commands_created = 1
	end

	utils.ensure_directory(utils.data_dir)
end

return M
