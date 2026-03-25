local utils = require("local-docs.utils")

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
	local instance = { doc = doc }
	setmetatable(instance, { __index = self })
	return instance
end

--- Defines an adapter for pulling builtin functions from official language
--- doc specifications and storing them in language/builtin/(type|function).md
--- @param crawler CrawlerConfig: The crawler configuration to use for fetching and parsing the documentation
function M:config_builtins(crawler)
	local path = utils.data_dir .. self.doc .. "/builtin/"
	crawler:fetch_all_documentation(path)
end

function M:config_stdlib() end
function M:config_misc() end

return M
