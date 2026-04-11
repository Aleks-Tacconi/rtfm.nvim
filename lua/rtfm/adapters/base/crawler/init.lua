local Fetch = require("rtfm.adapters.base.crawler.fetch")
local Rules = require("rtfm.adapters.base.crawler.rules")
local Source = require("rtfm.adapters.base.crawler.source")
local Transform = require("rtfm.adapters.base.crawler.transform")
local Writer = require("rtfm.adapters.base.crawler.writer")
local utils = require("rtfm.utils")

local M = {}

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
			vim.schedule(step)
		end)
	end

	vim.schedule(step)
end

--- @class CrawlerConfig
--- @field url string
--- @field source_rules table[]
--- @field documentation_rules table[]
--- @field seed_sources string[]
--- @field dedupe_sources boolean
--- @field name_rule table
--- @field path_mapper fun(ctx: table): string|nil
--- @field sources string[]

--- Constructs a crawler configuration instance.
--- @param spec table
--- @return table
function M:new(spec)
	local instance = {
		url = spec.url,
		source_rules = spec.source_rules or {},
		documentation_rules = spec.documentation_rules or {},
		name_rule = spec.name_rule,
		seed_sources = spec.seed_sources or {},
		source_filter = spec.source_filter,
		path_mapper = spec.path_mapper,
		request_delay_ms = spec.request_delay_ms or 0,
		retry_failed_fetches = spec.retry_failed_fetches == true,
		retry_delay_ms = spec.retry_delay_ms or 3000,
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

--- Adds a source to the crawler configuration.
--- @param source string
--- @return nil
function M:add_source(source)
	local trimmed = vim.trim(Source.resolve(self.url, source))
	if self.source_filter and not self.source_filter(trimmed) then
		return
	end

	if self.dedupe_sources and self._source_set[trimmed] then
		return
	end

	if self.dedupe_sources then
		self._source_set[trimmed] = true
	end

	table.insert(self.sources, trimmed)
end

--- Discovers documentation sources asynchronously.
--- @param done function
--- @return nil
function M:fetch(done)
	if #self.source_rules == 0 then
		done(true)
		return
	end

	Fetch.fetch_html_async(self, self.url, function(ok, result)
		if not ok then
			done(false, result)
			return
		end

		local rules_ok, output = pcall(Rules.apply, result, self.source_rules)
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

--- Discovers documentation sources synchronously.
--- @return nil
function M:fetch_sync()
	if #self.source_rules == 0 then
		return
	end

	local html = Fetch.fetch_html_sync(self, self.url)
	if not html then
		error(string.format("could not fetch '%s'", self.url))
	end

	for _, source in ipairs(Rules.apply_sync(html, self.source_rules)) do
		self:add_source(source)
	end

	if #self.sources == 0 then
		error(string.format("no documentation sources discovered for '%s'", self.url))
	end
end

--- Fetches and writes one documentation source asynchronously.
--- @param source string
--- @param output_path string
--- @param done function
--- @return nil
function M:fetch_documentation(source, output_path, done)
	Fetch.defer(self.request_delay_ms, function()
		Fetch.fetch_html_async(self, source, function(ok, result)
			if not ok then
				done(false, result)
				return
			end

			local sections = { result }
			if #self.documentation_rules > 0 then
				local rules_ok, rules_or_err = pcall(Rules.apply, result, self.documentation_rules)
				if not rules_ok then
					done(false, rules_or_err)
					return
				end

				sections = rules_or_err
			end

			run_sequential(sections, function(section, index, next_section)
				local ctx = Source.section_context(source, section, index)
				local section_name = Transform.derive_section_name(section, self.name_rule)
				if not section_name then
					next_section(false, string.format("could not derive section name for '%s' section %d", source, index))
					return
				end

				local normalized_name = Transform.normalize_section_name(ctx.source_name, section_name)
				if not normalized_name then
					next_section(
						false,
						string.format("invalid normalized section name '%s' for '%s'", section_name, source)
					)
					return
				end

				ctx.section_name = section_name
				ctx.normalized_name = normalized_name
				local relative_path = Transform.relative_output_path(self, ctx)
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

					Writer.register_index_entry(self._index_entries, relative_path, ctx)
					next_section(true)
				end)
			end, done)
		end)
	end)
end

--- Fetches and writes one documentation source synchronously.
--- @param source string
--- @param output_path string
--- @return nil
function M:fetch_documentation_sync(source, output_path)
	Fetch.wait(self.request_delay_ms)
	local html = Fetch.fetch_html_sync(self, source)
	if not html then
		error(string.format("could not fetch '%s'", source))
	end

	local sections = { html }
	if #self.documentation_rules > 0 then
		sections = Rules.apply_sync(html, self.documentation_rules)
	end

	for index, section in ipairs(sections) do
		local ctx = Source.section_context(source, section, index)
		local section_name = Transform.derive_section_name(section, self.name_rule)
		if not section_name then
			error(string.format("could not derive section name for '%s' section %d", source, index))
		end

		local normalized_name = Transform.normalize_section_name(ctx.source_name, section_name)
		if not normalized_name then
			error(string.format("invalid normalized section name '%s' for '%s'", section_name, source))
		end

		ctx.section_name = section_name
		ctx.normalized_name = normalized_name
		local relative_path = Transform.relative_output_path(self, ctx)
		local file_path = output_path .. "/" .. relative_path .. ".md"
		utils.write_file(file_path, utils.html_to_markdown(section))
		Writer.register_index_entry(self._index_entries, relative_path, ctx)
	end
end

--- Fetches all queued documentation asynchronously and writes the scope index.
--- @param output_path string
--- @param done function
--- @return nil
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

		local write_ok, write_err = pcall(Writer.write_index, output_path, self._index_entries)
		if not write_ok then
			done(false, write_err)
			return
		end

		done(true)
	end)
end

--- Fetches all queued documentation synchronously and writes the scope index.
--- @param output_path string
--- @param opts table|nil
--- @return nil
function M:fetch_all_documentation_sync(output_path, opts)
	opts = opts or {}
	if #self.sources == 0 then
		error(string.format("no documentation sources queued for '%s'", self.url))
	end

	for index, source in ipairs(self.sources) do
		if opts.on_source then
			opts.on_source(source, index, #self.sources)
		end

		self:fetch_documentation_sync(source, output_path)
	end

	if #self._index_entries == 0 then
		error(string.format("no documentation entries extracted for '%s'", self.url))
	end

	Writer.write_index(output_path, self._index_entries)
end

return M
