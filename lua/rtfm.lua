local utils = require("rtfm.utils")
local Adapter = require("rtfm.abc-adapter.adapter")
local Browser = require("rtfm.browser")
local Viewer = require("rtfm.viewer")

local notify_backend = require("notify")

local M = {}

M.adapters = {
	python = "rtfm.adapters.python",
}

M.ensure_installed = {}
M._active_installs = {}
M._install_notifications = {}

local SPINNER_FRAMES = { "-", "\\", "|", "/" }

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

local function notify(message, level, should_notify, opts)
	if should_notify == false then
		return
	end

	return notify_backend(message, level, opts or {})
end

local function spinner_frame(state)
	local elapsed_ms = (vim.uv.hrtime() - state.started_at) / 1000000
	local frame_index = math.floor(elapsed_ms / state.interval_ms) % #SPINNER_FRAMES + 1
	return SPINNER_FRAMES[frame_index]
end

local function spinner_elapsed(state)
	local elapsed_ms = (vim.uv.hrtime() - state.started_at) / 1000000
	return string.format("%.1fs", elapsed_ms / 1000)
end

local function spinner_message(state)
	return string.format("%s %s (%s)", spinner_frame(state), state.message, spinner_elapsed(state))
end

local function render_install_notification(state, level)
	if not state then
		return
	end

	state.notification = notify(spinner_message(state), level or vim.log.levels.INFO, true, {
		title = "rtfm.nvim",
		replace = state.notification,
	}) or state.notification
end

local function start_install_notification(name, should_notify)
	if should_notify == false then
		return nil
	end

	local state = {
		name = name,
		message = string.format("Installing '%s'...", name),
		started_at = vim.uv.hrtime(),
		interval_ms = 80,
		notification = nil,
		timer = nil,
	}

	render_install_notification(state)

	state.timer = vim.uv.new_timer()
	if state.timer then
		state.timer:start(state.interval_ms, state.interval_ms, vim.schedule_wrap(function()
			render_install_notification(state)
		end))
	end

	M._install_notifications[name] = state
	return state
end

local function update_install_notification(state, message)
	if not state then
		return
	end

	state.message = message
	render_install_notification(state)
end

local function stop_install_notification(state, message, level)
	if not state then
		return
	end

	if state.timer then
		state.timer:stop()
		state.timer:close()
		state.timer = nil
	end

	state.notification = notify(message, level, true, {
		title = "rtfm.nvim",
		replace = state.notification,
	}) or state.notification
	M._install_notifications[state.name] = nil
end

local function scope_lock_key(adapter, scope)
	return string.format("%s:%s", adapter.doc, scope.dir)
end

local function acquire_scope_locks(adapter)
	local keys = {}

	for _, scope in ipairs(Adapter.SCOPES) do
		if adapter.spec[scope.spec_key] then
			local key = scope_lock_key(adapter, scope)
			if M._active_installs[key] then
				return nil, string.format("Install already running for '%s' %s", adapter.doc, scope.dir)
			end

			table.insert(keys, key)
		end
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
	local scopes = {}
	for _, scope in ipairs(Adapter.SCOPES) do
		if adapter.spec[scope.spec_key] then
			table.insert(scopes, scope)
		end
	end
	return scopes
end

local function run_scopes(adapter, scopes, opts, done)
	local index = 1

	local function step()
		local scope = scopes[index]
		if not scope then
			done(true)
			return
		end

		update_install_notification(opts.notification, string.format("Installing '%s' %s (%d/%d)", adapter.doc, scope.dir, index, #scopes))
		adapter[scope.method](adapter, function(ok, err)
			if not ok then
				done(false, err)
				return
			end

			index = index + 1
			step()
		end)
	end

	step()
end

function M.register_adapter(name, module_path)
	M.adapters[name] = module_path
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

	local notification = start_install_notification(name, notify_enabled)

	run_scopes(adapter, enabled_scopes(adapter), { notify = notify_enabled, notification = notification }, function(install_ok, install_err)
		release_scope_locks(locks)

		if not install_ok then
			stop_install_notification(notification, install_err, vim.log.levels.ERROR)
			if opts.on_done then
				opts.on_done(false, install_err)
			end
			return
		end

		stop_install_notification(notification, string.format("Installed '%s'", name), vim.log.levels.INFO)
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
	if vim.g.rtfm_commands_created ~= 1 then
		create_user_commands()
		vim.g.rtfm_commands_created = 1
	end

	M.ensure_installed = (opts and opts.ensure_installed) or {}

	utils.ensure_directory(utils.data_dir)

	for _, name in ipairs(M.ensure_installed) do
		vim.schedule(function()
			M.install_adapter(name, { source = "startup" })
		end)
	end
end

return M
