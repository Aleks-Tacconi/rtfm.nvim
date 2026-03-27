--- Crawler configurtaion for usage with the abstract base adapter.

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

local function source_key(source)
	local key = source:gsub("^https?://", "")
	key = key:gsub("[^%w]+", "_"):lower()
	key = key:gsub("^_+", ""):gsub("_+$", "")

	if key == "" then
		return "source"
	end

	return key:sub(1, 32)
end

--- Derives a section name from the given section content using the provided rule.
--- @param section string: The content of the documentation section to derive a name for
--- @param rule Rule: The rule to apply to the section content to derive the name
--- @return string|nil: The derived section name, sanitized for use as a file name.
local function derive_section_name(section, rule)
	if not rule then
		return nil
	end

	local output = rule:apply(section)
	local name = output and output[1]
	if not name then
		return nil
	end

	name = name:gsub("%s+", "_")
	name = name:gsub("[^%w_]", "")
	name = name:lower()

	if name == "" then
		return nil
	end

	return name
end

--- @class CrawlerConfig
--- @field url string: The URL to pull documentation from
--- @field source_rules Rule[]: The chain of rules to discover documentation source links from the root URL page
--- @field documentation_rules Rule[]: The chain of rules to split fetched documentation pages into sections
--- @field name_rule Rule: The rule to derive section names from section content, used for naming the output files
--- @field seed_sources string[]: Optional initial source URLs to fetch documentation from
--- @field dedupe_sources boolean: Whether to deduplicate discovered/seeded source URLs
--- @field sources string[] Collected documentation source URLs
local M = {}

--- Contructs a new crawler configuration instance
--- @param spec table
function M:new(spec)
	local instance = {
		url = spec.url,
		source_rules = spec.source_rules or {},
		documentation_rules = spec.documentation_rules or {},
		name_rule = spec.name_rule,
		seed_sources = spec.seed_sources or {},
		dedupe_sources = spec.dedupe_sources ~= false,
		sources = {},
		_source_set = {},
		_written_name_counts = {},
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
	local trimmed = vim.trim(source)

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

--- Fetches the documentation from a given source URL, applies the documentation rules to split it into sections,
--- Then stores each section under output_path/(section_name).md, where section_name is derived from the
--- section content
--- @param source string: The URL of the documentation source to fetch
--- @param output_path string: The directory path to store the fetched documentation sections in
function M:fetch_documentation(source, output_path)
	local html = utils.curl(source)
	if not html then
		return
	end

	local sections = #self.documentation_rules > 0 and apply_rule_chain(html, self.documentation_rules) or { html }

	for index, section in ipairs(sections) do
		local section_name = derive_section_name(section, self.name_rule)
		if not section_name then
			section_name = "section_" .. source_key(source) .. "_" .. index
		end

		local existing = self._written_name_counts[section_name] or 0
		self._written_name_counts[section_name] = existing + 1
		if existing > 0 then
			section_name = section_name .. "_" .. (existing + 1)
		end

		local file_path = output_path .. "/" .. section_name .. ".md"
		utils.write_file(file_path, section)
	end
end

--- Fetches the documentation from all collected source URLs and stores them under output_path/(section_name).md
--- @param output_path string: The directory path to store the fetched documentation sections in
function M:fetch_all_documentation(output_path)
	for _, source in ipairs(self.sources) do
		self:fetch_documentation(source, output_path)
	end
end

return M
