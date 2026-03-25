--- Crawler configurtaion for usage with the abstract base adapter.

local rule_utils = require("local-docs.abc-adapter.rule.utils")
local utils = require("local-docs.utils")

--- Derives a section name from the given section content using the provided rule.
--- @param section string: The content of the documentation section to derive a name for
--- @param rule Rule: The rule to apply to the section content to derive the name
--- @return string: The derived section name, sanitized for use as a file name.
---                 If the rule fails to derive a name, returns "unknown_section".
local function derive_section_name(section, rule)
	local name = rule:apply(section)[1]
	if not name then
		return "unknown_section"
	end

	name = name:gsub("%s+", "_")
	name = name:gsub("[^%w_]", "")
	name = name:lower()

	if name == "" then
		return "unknown_section"
	end

	return name
end

--- @class CrawlerConfig
--- @field url string: The URL to pull documentation from
--- @field source_rules Rule[]: The chain of rules to discover documentation source links from the root URL page
--- @field documentation_rules Rule[]: The chain of rules to split fetched documentation pages into sections
--- @field name_rule Rule: The rule to derive section names from section content, used for naming the output files
--- @field sources string[] Collected documentation source URLs
local M = {}

--- Contructs a new crawler configuration instance
function M:new(url, source_rules, documentation_rules, name_rule)
	local instance = {
		url = url,
		source_rule = source_rules,
		documentation_rule = documentation_rules,
		name_rule = name_rule,
		sources = {},
	}

	setmetatable(instance, { __index = self })
	return instance
end

--- Adds a source to the crawler configuration
--- @param source string: The URL of the documentation source to add
function M:add_source(source)
	table.insert(self.sources, source)
end

--- Fetches the root URL page, applies the source rules to discover documentation source links,
--- and adds them to the crawler configuration
function M:fetch()
	local html = utils.curl(self.url, "")
	local output = rule_utils.apply_rule_chain(html, self.source_rules)

	for _, source in ipairs(output) do
		if utils.ensure_url_format(source, "Invalid source URL: " .. source) then
			self:add_source(source)
		end
	end
end

--- Fetches the documentation from a given source URL, applies the documentation rules to split it into sections,
--- Then stores each section under output_path/(section_name).md, where section_name is derived from the
--- section content
--- @param source string: The URL of the documentation source to fetch
--- @param output_path string: The directory path to store the fetched documentation sections in
function M:fetch_documentation(source, output_path)
	local html = utils.curl(source, "")
	local sections = rule_utils.apply_rule_chain(html, self.documentation_rules)

	for _, section in ipairs(sections) do
		local section_name = derive_section_name(section, self.name_rule)
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
