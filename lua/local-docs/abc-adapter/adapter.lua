local CrawlerConfig = require("local-docs.abc-adapter.crawler-config")
local utils = require("local-docs.utils")

--- @class Adapter
--- Abstract base adapter class, defines the interface for pulling doc specifications
--- and storing them in language/option/(data_structure|type|function).md
--- @field doc string: The language / framework the documentation being pulled from is for, used for display purposes
local M = {}

M.SCOPES = {
	{ spec_key = "builtins", method = "config_builtins", dir = "builtin" },
	{ spec_key = "stdlib", method = "config_stdlib", dir = "stdlib" },
	{ spec_key = "misc", method = "config_misc", dir = "misc" },
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
--- @param crawler_spec table
function M:_run_scope(scope_dir, crawler_spec)
	local crawler = CrawlerConfig:new(crawler_spec)

	crawler:fetch()

	local path = utils.data_dir .. self.doc .. "/" .. scope_dir .. "/"
	crawler:fetch_all_documentation(path)
end

--- Defines an adapter for pulling builtin functions from official language
--- doc specifications and storing them in language/builtin/(type|function).md
--- @param crawler_spec table: declarative crawler spec
function M:config_builtins(crawler_spec)
	self:_run_scope("builtin", crawler_spec)
end

--- @param crawler_spec table
function M:config_stdlib(crawler_spec)
	self:_run_scope("stdlib", crawler_spec)
end

--- @param crawler_spec table
function M:config_misc(crawler_spec)
	self:_run_scope("misc", crawler_spec)
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
	local adapter = {
		doc = spec.doc,
		spec = spec,
	}
	setmetatable(adapter, { __index = M })

	function adapter:new()
		return M.new(self, self.doc)
	end

	for _, scope in ipairs(M.SCOPES) do
		if spec[scope.spec_key] then
			adapter[scope.method] = function(self)
				self:_run_scope(scope.dir, self.spec[scope.spec_key])
			end
		end
	end

	return adapter
end

return M
