--- Crawler configurtaion for usage with the abstract base adapter.

local path_utils = require("local-docs.path")
local utils = require("local-docs.utils")

local function apply_rule_chain(html, rules)
	local results = { html }

	for _, rule in ipairs(rules) do
		local next_results = {}
		for _, fragment in ipairs(results) do
			vim.list_extend(next_results, rule:apply(fragment))
		end
		results = next_results
	end

	return results
end

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

local function resolve_source(base_url, source)
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

local function url_path(url)
	return url:match("^https?://[^/]+(/[^?#]*)") or "/"
end

local function source_name(url)
	local source_path = url_path(url)
	local basename = source_path:match("/([^/]+)$") or "index"
	return (basename:gsub("%.html?$", ""))
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

local function section_context(source, section, index)
	return {
		source_url = source,
		source_path = url_path(source),
		source_name = source_name(source),
		section_html = section,
		section_index = index,
		section_id = section_id(section),
		heading_text = heading_text(section),
	}
end

local function display_title(ctx, relative_path)
	if ctx.heading_text and ctx.heading_text ~= "" then
		return ctx.heading_text
	end

	if ctx.section_id and ctx.section_id ~= "" then
		return ctx.section_id
	end

	return relative_path:match("([^/]+)$") or relative_path
end

local function register_index_entry(entries_by_dir, order_by_dir, relative_path, ctx)
	local directory = vim.fn.fnamemodify(relative_path, ":h")
	if directory == "." then
		directory = ""
	end

	if not entries_by_dir[directory] then
		entries_by_dir[directory] = {}
		table.insert(order_by_dir, directory)
	end

	table.insert(entries_by_dir[directory], {
		path = relative_path,
		title = display_title(ctx, relative_path),
	})
end

local function write_indexes(output_path, entries_by_dir, order_by_dir)
	for _, directory in ipairs(order_by_dir) do
		local lines = {}
		local entries = entries_by_dir[directory]

		for index, entry in ipairs(entries) do
			local relative_target = entry.path:match("([^/]+)$") or entry.path
			table.insert(lines, string.format("%d. [%s](./%s.md)", index, entry.title, relative_target))
		end

		local index_path = output_path .. "/_index.md"
		if directory ~= "" then
			index_path = output_path .. "/" .. directory .. "/_index.md"
		end

		utils.write_file(index_path, table.concat(lines, "\n") .. "\n")
	end
end

--- @class CrawlerConfig
--- @field url string: The URL to pull documentation from
--- @field source_rules Rule[]: The chain of rules to discover documentation source links from the root URL page
--- @field documentation_rules Rule[]: The chain of rules to split fetched documentation pages into sections
--- @field seed_sources string[]: Optional initial source URLs to fetch documentation from
--- @field dedupe_sources boolean: Whether to deduplicate discovered/seeded source URLs
--- @field path_mapper fun(ctx: table): string Maps a section context to a relative output path without extension
--- @field sources string[] Collected documentation source URLs
local M = {}

--- Contructs a new crawler configuration instance
--- @param spec table
function M:new(spec)
	local instance = {
		url = spec.url,
		source_rules = spec.source_rules or {},
		documentation_rules = spec.documentation_rules or {},
		path_mapper = spec.path_mapper,
		seed_sources = spec.seed_sources or {},
		dedupe_sources = spec.dedupe_sources ~= false,
		sources = {},
		_source_set = {},
		_index_entries = {},
		_index_order = {},
	}

	setmetatable(instance, { __index = self })

	for _, source in ipairs(instance.seed_sources) do
		instance:add_source(source)
	end

	return instance
end

--- Adds a source to the crawler configuration
--- @param source string: The URL of the documentation source to add
function M:add_source(source)
	local trimmed = vim.trim(resolve_source(self.url, source))

	if self.dedupe_sources and self._source_set[trimmed] then
		return
	end

	if self.dedupe_sources then
		self._source_set[trimmed] = true
	end

	table.insert(self.sources, trimmed)
end

--- Fetches the root URL page, applies the source rules to discover documentation source links,
--- and adds them to the crawler configuration
function M:fetch()
	if #self.source_rules == 0 then
		return
	end

	local html = utils.curl(self.url)
	if not html then
		return
	end

	local output = apply_rule_chain(html, self.source_rules)

	for _, source in ipairs(output) do
		self:add_source(source)
	end
end

--- Fetches a documentation source, splits it into sections, and writes each section to the
--- relative markdown path returned by path_mapper(ctx).
--- @param source string: The URL of the documentation source to fetch
--- @param output_path string: The directory path to store the fetched documentation sections in
function M:fetch_documentation(source, output_path)
	local html = utils.curl(source)
	if not html then
		return
	end

	local sections = #self.documentation_rules > 0 and apply_rule_chain(html, self.documentation_rules) or { html }

	for index, section in ipairs(sections) do
		local ctx = section_context(source, section, index)
		local relative_path = path_utils.normalize(self.path_mapper(ctx))
		local file_path = output_path .. "/" .. relative_path .. ".md"
		utils.write_file(file_path, utils.html_to_markdown(section))
		register_index_entry(self._index_entries, self._index_order, relative_path, ctx)
	end
end

--- Fetches the documentation from all collected source URLs and stores them under output_path.
--- @param output_path string: The directory path to store the fetched documentation sections in
function M:fetch_all_documentation(output_path)
	for _, source in ipairs(self.sources) do
		self:fetch_documentation(source, output_path)
	end

	write_indexes(output_path, self._index_entries, self._index_order)
end

return M
