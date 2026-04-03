local utils = require("rtfm.utils")

local M = {}

local INDEX_LINE_PATTERN = "^(%d+)%. (.+) %- (.+)%.md$"

--- Returns the absolute scope directory for an adapter scope.
--- @param adapter string
--- @param scope_dir string
--- @return string
local function scope_path(adapter, scope_dir)
	return string.format("%s%s/%s", utils.data_dir, adapter, scope_dir)
end

--- Parses a generated `_index.md` line into a structured entry.
--- @param adapter string
--- @param scope_dir string
--- @param line string
--- @param line_number integer
--- @return table
local function parse_index_line(adapter, scope_dir, line, line_number)
	local ordinal, title, relative_path = line:match(INDEX_LINE_PATTERN)
	if not ordinal then
		error(string.format("invalid _index.md line %d for '%s/%s': %s", line_number, adapter, scope_dir, line))
	end

	local source = relative_path:match("^([^/]+)") or relative_path
	return {
		ordinal = tonumber(ordinal),
		title = vim.trim(title),
		relative_path = relative_path,
		absolute_path = string.format("%s/%s.md", scope_path(adapter, scope_dir), relative_path),
		source = source,
	}
end

--- Returns a sorted list of registered adapters.
--- @param adapters table<string, string>
--- @return string[]
function M.list_adapters(adapters)
	local names = {}
	for name, _ in pairs(adapters or {}) do
		table.insert(names, name)
	end

	table.sort(names)
	return names
end

--- Returns scope descriptors for an adapter.
--- @param adapter table
--- @param scopes table[]
--- @return table[]
function M.list_scopes(adapter, scopes)
	local available = {}
	for _, scope in ipairs(scopes or {}) do
		if adapter.spec[scope.spec_key] then
			table.insert(available, {
				dir = scope.dir,
				method = scope.method,
				spec_key = scope.spec_key,
				label = scope.dir,
			})
		end
	end

	return available
end

--- Loads and parses the ordered index for an adapter scope.
--- @param adapter string
--- @param scope_dir string
--- @return table
function M.load_scope_index(adapter, scope_dir)
	local index_path = string.format("%s/_index.md", scope_path(adapter, scope_dir))
	if vim.fn.filereadable(index_path) ~= 1 then
		error(string.format("No index found for '%s/%s'. Install it from :RtfmManage first.", adapter, scope_dir))
	end

	local lines = vim.fn.readfile(index_path)
	local entries = {}
	for line_number, line in ipairs(lines) do
		if vim.trim(line) ~= "" then
			table.insert(entries, parse_index_line(adapter, scope_dir, line, line_number))
		end
	end

	if #entries == 0 then
		error(string.format("Index for '%s/%s' is empty. Reinstall it from :RtfmManage.", adapter, scope_dir))
	end

	return {
		adapter = adapter,
		scope = scope_dir,
		index_path = index_path,
		entries = entries,
	}
end

--- Groups ordered entries by source directory.
--- @param entries table[]
--- @return table[]
function M.group_sources(entries)
	local grouped = {}
	local by_name = {}

	for _, entry in ipairs(entries or {}) do
		local source = by_name[entry.source]
		if not source then
			source = {
				name = entry.source,
				entries = {},
			}
			by_name[entry.source] = source
			table.insert(grouped, source)
		end

		table.insert(source.entries, entry)
	end

	return grouped
end

return M
