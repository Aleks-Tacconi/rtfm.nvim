local Adapter = require("rtfm.adapters.base.adapter")

local M = {}

--- Builds a stable lock key for an adapter scope.
--- @param adapter table
--- @param scope table
--- @return string
local function scope_lock_key(adapter, scope)
	local key = scope.dir ~= "" and scope.dir or scope.spec_key
	return string.format("%s:%s", adapter.doc, key)
end

--- Acquires all scope locks for an adapter.
--- @param active_installs table<string, boolean>
--- @param adapter table
--- @return string[]|nil, string|nil
function M.acquire(active_installs, adapter)
	local keys = {}

	for _, scope in ipairs(Adapter.scopes_for(adapter)) do
		local key = scope_lock_key(adapter, scope)
		if active_installs[key] then
			return nil, string.format("Install already running for '%s' %s", adapter.doc, scope.label or scope.dir)
		end

		table.insert(keys, key)
	end

	for _, key in ipairs(keys) do
		active_installs[key] = true
	end

	return keys, nil
end

--- Releases previously acquired scope locks.
--- @param active_installs table<string, boolean>
--- @param keys string[]|nil
--- @return nil
function M.release(active_installs, keys)
	for _, key in ipairs(keys or {}) do
		active_installs[key] = nil
	end
end

return M
