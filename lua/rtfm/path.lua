local M = {}

--- Returns a sanitized path segment for generated docs.
--- @param segment string
--- @return string
local function normalize_segment(segment)
	local normalized = vim.trim(segment)
	normalized = normalized:gsub("[^%w_-]+", "_")
	normalized = normalized:gsub("_+", "_")
	normalized = normalized:gsub("[_%.%-]+$", "")
	return normalized
end

--- Returns a relative output path suitable for writing markdown docs.
--- @param path string
--- @return string
function M.normalize(path)
	if type(path) ~= "string" then
		error("output path must be a string")
	end

	local normalized = vim.trim(path)
	normalized = normalized:gsub("\\", "/")
	normalized = normalized:gsub("^/+", "")
	normalized = normalized:gsub("/+$", "")

	if normalized == "" then
		error("output path must be a non-empty relative path")
	end

	if normalized:find("//", 1, true) then
		error(string.format("invalid output path '%s': empty path segments are not allowed", normalized))
	end

	if normalized:sub(-3) == ".md" then
		error(string.format("invalid output path '%s': omit the '.md' extension", normalized))
	end

	local segments = {}
	for segment in normalized:gmatch("[^/]+") do
		if segment == "." or segment == ".." then
			error(string.format("invalid output path '%s': relative segments are not allowed", normalized))
		end

		local sanitized = normalize_segment(segment)
		if sanitized == "" then
			error(string.format("invalid output path '%s': path segments must contain visible characters", normalized))
		end

		table.insert(segments, sanitized)
	end

	return table.concat(segments, "/")
end

return M
