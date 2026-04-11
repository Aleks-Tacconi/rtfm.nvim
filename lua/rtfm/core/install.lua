local Adapter = require("rtfm.abc-adapter.adapter")
local Progress = require("rtfm.progress")
local utils = require("rtfm.utils")

local ScopeLock = require("rtfm.core.scope_lock")

local M = {}

local function notify(message, level, should_notify, opts)
	if should_notify == false then
		return
	end

	return vim.notify(message, level, opts or {})
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

local function progress_lines(scopes, active_index, active_status, detail)
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

--- Installs an adapter with modal progress UI.
--- @param name string
--- @param load_adapter fun(name: string): table
--- @param active_installs table<string, boolean>
--- @return nil
function M.install_modal(name, load_adapter, active_installs)
	local adapter = load_adapter(name):new()
	local locks, lock_err = ScopeLock.acquire(active_installs, adapter)
	if not locks then
		error(lock_err)
	end

	local scopes = enabled_scopes(adapter)
	local detail = nil
	Progress.open(string.format(" 󰇚  Installing %s", name))
	Progress.set_lines(progress_lines(scopes, 1, "running", detail))

	local ok, err = xpcall(function()
		run_scopes_sync(adapter, scopes, function(_, index)
			detail = nil
			Progress.set_lines(progress_lines(scopes, index, "running", detail))
		end, function(_, index, _, source, source_index, source_total)
			detail = string.format("source %d/%d  %s", source_index, source_total, source)
			Progress.set_lines(progress_lines(scopes, index, "running", detail))
		end)
	end, debug.traceback)

	if ok then
		Progress.set_lines(progress_lines(scopes, #scopes + 1, "done", nil))
	end

	Progress.close()
	ScopeLock.release(active_installs, locks)

	if not ok then
		error(err)
	end

	vim.notify(string.format("Installed '%s'", name), vim.log.levels.INFO)
end

--- Removes an adapter with modal progress UI.
--- @param name string
--- @return nil
function M.uninstall_modal(name)
	Progress.open(string.format("Removing %s", name))
	Progress.set_lines({ string.format(" 󰆴  Removing adapter  %s", name) })
	local ok, err = utils.safe_delete(utils.data_dir .. name)
	Progress.close()
	if not ok then
		error(err)
	end

	vim.notify(string.format("Removed '%s'", name), vim.log.levels.INFO)
end

--- Installs an adapter in the background.
--- @param name string
--- @param load_adapter fun(name: string): table
--- @param active_installs table<string, boolean>
--- @param opts table|nil
--- @return boolean
function M.install(name, load_adapter, active_installs, opts)
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
	local locks, lock_err = ScopeLock.acquire(active_installs, adapter)
	if not locks then
		notify(lock_err, vim.log.levels.WARN, notify_enabled)
		if opts.on_done then
			opts.on_done(false, lock_err)
		end
		return false
	end

	notify(string.format("Installing '%s' in background...", name), vim.log.levels.INFO, notify_enabled)

	run_scopes(adapter, enabled_scopes(adapter), { notify = notify_enabled }, function(install_ok, install_err)
		ScopeLock.release(active_installs, locks)

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

--- Removes an installed adapter directory.
--- @param name string
--- @return boolean
function M.uninstall(name)
	local path = utils.data_dir .. name
	vim.fn.delete(path, "rf")
	vim.notify(string.format("Uninstalled '%s'", name), vim.log.levels.INFO)
	return true
end

return M
