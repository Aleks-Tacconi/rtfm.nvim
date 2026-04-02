--- Crawler configurtaion for usage with the abstract base adapter.

local path_utils = require("rtfm.path")
local utils = require("rtfm.utils")

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

local function derive_section_name(section, rule)
	local output = rule:apply(section)
	local name = output and output[1]
	if not name or name == "" then
		local fallback_id = section:match(' id="([^"]+)"') or section:match(" id='([^']+)'")
		if fallback_id and fallback_id ~= "" then
			return vim.trim(fallback_id)
		end

		local desc_class = section:match('<span class="sig%-prename descclassname"><span class="pre">(.-)</span></span>')
		local desc_name = section:match('<span class="sig%-name descname"><span class="pre">(.-)</span></span>')
		if desc_name and desc_name ~= "" then
			return vim.trim((desc_class or "") .. desc_name)
		end

		return nil
	end

	return vim.trim(name)
end

local function normalize_section_name(source, section_name)
	local normalized = section_name
	local prefix = source .. "."

	if normalized:sub(1, #prefix) == prefix then
		normalized = normalized:sub(#prefix + 1)
	end

	normalized = normalized:gsub("%._+", "__")
	normalized = normalized:gsub("%.", "__")

	if normalized == "" then
		return nil
	end

	return normalized
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
		return ctx.heading_text:gsub("¶", ""):gsub("%s+$", "")
	end

	if ctx.section_id and ctx.section_id ~= "" then
		return ctx.section_id
	end

	return relative_path:match("([^/]+)$") or relative_path
end

local function register_index_entry(entries, relative_path, ctx)
	table.insert(entries, {
		path = relative_path,
		title = display_title(ctx, relative_path),
	})
end


local function write_index(output_path, entries)
	if #entries == 0 then
		return
	end

	local lines = {}
	for index, entry in ipairs(entries) do
		table.insert(lines, string.format("%d. %s - %s.md", index, entry.title, entry.path))
	end

	utils.write_file(output_path .. "/_index.md", table.concat(lines, "\n") .. "\n")
end

local function run_sequential(items, iterator, done)
	local index = 1

	local function step()
		local item = items[index]
		if not item then
			done(true)
			return
		end

		iterator(item, index, function(ok, err)
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

--- @class CrawlerConfig
--- @field url string: The URL to pull documentation from
--- @field source_rules Rule[]: The chain of rules to discover documentation source links from the root URL page
--- @field documentation_rules Rule[]: The chain of rules to split fetched documentation pages into sections
--- @field seed_sources string[]: Optional initial source URLs to fetch documentation from
--- @field dedupe_sources boolean: Whether to deduplicate discovered/seeded source URLs
--- @field name_rule Rule Derives a stable section name from extracted section html
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
		_index_entries = {},
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
function M:fetch(done)
	if #self.source_rules == 0 then
		done(true)
		return
	end

	utils.curl_async(self.url, function(ok, result)
		if not ok then
			done(false, result)
			return
		end

		local rules_ok, output = pcall(apply_rule_chain, result, self.source_rules)
		if not rules_ok then
			done(false, output)
			return
		end

		for _, source in ipairs(output) do
			self:add_source(source)
		end

		if #self.sources == 0 then
			done(false, string.format("no documentation sources discovered for '%s'", self.url))
			return
		end

		done(true)
	end)
end

--- Fetches a documentation source, splits it into sections, derives stable names from name_rule,
--- and writes the sections under source_name/normalized_name.md.
--- @param source string: The URL of the documentation source to fetch
--- @param output_path string: The directory path to store the fetched documentation sections in
function M:fetch_documentation(source, output_path, done)
	utils.curl_async(source, function(ok, result)
		if not ok then
			done(false, result)
			return
		end

		local sections = { result }
		if #self.documentation_rules > 0 then
			local rules_ok, rules_or_err = pcall(apply_rule_chain, result, self.documentation_rules)
			if not rules_ok then
				done(false, rules_or_err)
				return
			end

			sections = rules_or_err
		end

		local source_key = source_name(source):gsub("%.", "/")

		run_sequential(sections, function(section, index, next_section)
			local ctx = section_context(source, section, index)
			local section_name = derive_section_name(section, self.name_rule)
			if not section_name then
				next_section(false, string.format("could not derive section name for '%s' section %d", source, index))
				return
			end

			local normalized_name = normalize_section_name(ctx.source_name, section_name)
			if not normalized_name then
				next_section(false, string.format("invalid normalized section name '%s' for '%s'", section_name, source))
				return
			end

			local relative_path = path_utils.normalize(string.format("%s/%s", source_key, normalized_name))
			local file_path = output_path .. "/" .. relative_path .. ".md"

			utils.html_to_markdown_async(section, function(markdown_ok, markdown_or_err)
				if not markdown_ok then
					next_section(false, markdown_or_err)
					return
				end

				local write_ok, write_err = pcall(utils.write_file, file_path, markdown_or_err)
				if not write_ok then
					next_section(false, write_err)
					return
				end

				register_index_entry(self._index_entries, relative_path, ctx)
				next_section(true)
			end)
		end, done)
	end)
end

--- Fetches the documentation from all collected source URLs and stores them under output_path.
--- @param output_path string: The directory path to store the fetched documentation sections in
function M:fetch_all_documentation(output_path, done)
	if #self.sources == 0 then
		done(false, string.format("no documentation sources queued for '%s'", self.url))
		return
	end

	run_sequential(self.sources, function(source, _, next_source)
		self:fetch_documentation(source, output_path, next_source)
	end, function(ok, err)
		if not ok then
			done(false, err)
			return
		end

		if #self._index_entries == 0 then
			done(false, string.format("no documentation entries extracted for '%s'", self.url))
			return
		end

		local write_ok, write_err = pcall(write_index, output_path, self._index_entries)
		if not write_ok then
			done(false, write_err)
			return
		end

		done(true)
	end)
end

return M
