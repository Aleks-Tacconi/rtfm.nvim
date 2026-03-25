local CrawlerConfig = require("local-docs.abc-adapter.crawler-config")
local utils = require("local-docs.utils")

local function ensure_crawler(crawler_or_spec)
	if not crawler_or_spec then
		return nil
	end

	if type(crawler_or_spec) == "table" and type(crawler_or_spec.fetch_all_documentation) == "function" then
		return crawler_or_spec
	end

	return CrawlerConfig:new(crawler_or_spec)
end

local function validate_adapter_spec(spec)
	if type(spec) ~= "table" then
		error("Adapter.define: spec must be a table")
	end

	if type(spec.doc) ~= "string" or not spec.doc:match("^[%w_-]+$") then
		error("Adapter.define: spec.doc must match ^[%w_-]+$")
	end
end

--- @class Adapter
--- Abstract base adapter class, defines the interface for pulling doc specifications
--- and storing them in language/option/(data_structure|type|function).md
--- @field abstract boolean: Indicates that this is an abstract base class and should not be instantiated directly
--- @field doc string: The language / framework the documentation being pulled from is for, used for display purposes
local M = {
	abstract = true,
}

--- Constructs a new adapter instance
--- @param doc string: The language / framework the documentation being pulled from is for, used for display purposes
function M:new(doc)
	local instance = { doc = doc, abstract = false }
	setmetatable(instance, { __index = self })
	return instance
end

--- Runs crawler extraction for a given output scope directory.
--- @param scope_dir string
--- @param crawler_or_spec CrawlerConfig|table
function M:_run_scope(scope_dir, crawler_or_spec)
	if type(self.doc) ~= "string" or self.doc == "" then
		error("Adapter: missing doc identifier")
	end

	local crawler = ensure_crawler(crawler_or_spec)
	if not crawler then
		return
	end

	crawler:fetch()

	local path = utils.data_dir .. self.doc .. "/" .. scope_dir .. "/"
	crawler:fetch_all_documentation(path)
end

--- Defines an adapter for pulling builtin functions from official language
--- doc specifications and storing them in language/builtin/(type|function).md
--- @param crawler_or_spec CrawlerConfig|table: crawler config instance or declarative crawler spec
function M:config_builtins(crawler_or_spec)
	self:_run_scope("builtin", crawler_or_spec)
end

--- @param crawler_or_spec CrawlerConfig|table
function M:config_stdlib(crawler_or_spec)
	self:_run_scope("stdlib", crawler_or_spec)
end

--- @param crawler_or_spec CrawlerConfig|table
function M:config_misc(crawler_or_spec)
	self:_run_scope("misc", crawler_or_spec)
end

--- @class AdapterSpec
--- @field doc string
--- @field builtins table|nil
--- @field stdlib table|nil
--- @field misc table|nil

--- Defines a declarative adapter with preconfigured crawler specs.
--- @param spec AdapterSpec
--- @return Adapter
function M.define(spec)
	validate_adapter_spec(spec)

	local adapter = {
		abstract = false,
		doc = spec.doc,
		spec = vim.deepcopy(spec),
	}
	setmetatable(adapter, { __index = M })

	function adapter:new()
		return M.new(self, self.doc)
	end

	if spec.builtins then
		function adapter:config_builtins()
			self:_run_scope("builtin", self.spec.builtins)
		end
	end

	if spec.stdlib then
		function adapter:config_stdlib()
			self:_run_scope("stdlib", self.spec.stdlib)
		end
	end

	if spec.misc then
		function adapter:config_misc()
			self:_run_scope("misc", self.spec.misc)
		end
	end

	return adapter
end

return M
