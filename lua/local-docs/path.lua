local M = {}

--- Returns a relative output path suitable for writing markdown docs.
--- @param path string
--- @return string
function M.normalize(path)
	if type(path) ~= "string" then
		error("path_mapper(ctx) must return a string")
	end

	local normalized = vim.trim(path)
	normalized = normalized:gsub("\\", "/")
	normalized = normalized:gsub("^/+", "")
	normalized = normalized:gsub("/+$", "")

	if normalized == "" then
		error("path_mapper(ctx) must return a non-empty relative path")
	end

	if normalized:find("//", 1, true) then
		error(string.format("invalid output path '%s': empty path segments are not allowed", normalized))
	end

	if normalized:sub(-3) == ".md" then
		error(string.format("invalid output path '%s': omit the '.md' extension", normalized))
	end

	for segment in normalized:gmatch("[^/]+") do
		if segment == "." or segment == ".." then
			error(string.format("invalid output path '%s': relative segments are not allowed", normalized))
		end
		if segment:match("^[%s.]+$") then
			error(string.format("invalid output path '%s': path segments must contain visible characters", normalized))
		end
	end

	return normalized
end

return M
