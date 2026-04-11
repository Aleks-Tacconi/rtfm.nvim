local M = {}

--- Removes HTML tags and collapses whitespace.
--- @param value string
--- @return string
local function strip_tags(value)
	local stripped = value:gsub("<[^>]+>", " ")
	stripped = stripped:gsub("&nbsp;", " ")
	stripped = stripped:gsub("&amp;", "&")
	stripped = stripped:gsub("&lt;", "<")
	stripped = stripped:gsub("&gt;", ">")
	return vim.trim(stripped:gsub("%s+", " "))
end

local function escape_pattern(value)
	return value:gsub("([^%w])", "%%%1")
end

--- Resolves a discovered source against the crawler root URL.
--- @param base_url string
--- @param source string
--- @return string
function M.resolve(base_url, source)
	if source:match("^https?://") then
		return source
	end

	local root = base_url:match("^(https?://[^/]+)")
	if not root then
		return source
	end

	if source:sub(1, 1) == "/" then
		return root .. source
	end

	local base_dir = base_url:match("^(https?://.*/)") or (root .. "/")
	local resolved = base_dir .. source
	local base_prefix = escape_pattern(root)

	resolved = resolved:gsub("([^:])/+", "%1/")
	while resolved:match(base_prefix .. "/[^/]+/%.%./") do
		resolved = resolved:gsub("(" .. base_prefix .. "/.-)/[^/]+/%.%./", "%1/")
	end

	return resolved
end

--- Returns the path component for a URL.
--- @param url string
--- @return string
function M.url_path(url)
	return url:match("^https?://[^/]+(/[^?#]*)") or "/"
end

--- Returns a stable source name for a URL.
--- @param url string
--- @return string
function M.source_name(url)
	local source_path = M.url_path(url)
	source_path = source_path:gsub("@[^/]+$", "")
	source_path = source_path:gsub("/+$", "")

	if source_path == "" or source_path == "/" then
		return "index"
	end

	if source_path:match("%.html?$") then
		local basename = source_path:match("/([^/]+)$") or "index"
		return (basename:gsub("%.html?$", ""))
	end

	return source_path:gsub("^/", "")
end

local function section_id(section)
	return section:match(' id="([^"]+)"') or section:match(" id='([^']+)'")
end

local function heading_text(section)
	local heading = section:match("<h[1-6][^>]*>(.-)</h[1-6]>")
	if not heading then
		return nil
	end

	local text = strip_tags(heading)
	if text == "" then
		return nil
	end

	return text
end

--- Builds shared section context for downstream transforms.
--- @param source string
--- @param section string
--- @param index integer
--- @return table
function M.section_context(source, section, index)
	return {
		source_url = source,
		source_path = M.url_path(source),
		source_name = M.source_name(source),
		section_html = section,
		section_index = index,
		section_id = section_id(section),
		heading_text = heading_text(section),
	}
end

return M
