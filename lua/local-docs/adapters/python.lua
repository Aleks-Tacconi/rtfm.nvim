local Adapter = require("local-docs.abc-adapter.adapter")
local CrawlerConfig = require("local-docs.abc-adapter.crawler-config")
local Rule = require("local-docs.abc-adapter.rule")

local ROOT_URL = "https://docs.python.org/3/reference/index.html"

local REFERENCE_PAGES = {
	"https://docs.python.org/3/reference/introduction.html",
	"https://docs.python.org/3/reference/lexical_analysis.html",
	"https://docs.python.org/3/reference/datamodel.html",
	"https://docs.python.org/3/reference/executionmodel.html",
	"https://docs.python.org/3/reference/import.html",
	"https://docs.python.org/3/reference/expressions.html",
	"https://docs.python.org/3/reference/simple_stmts.html",
	"https://docs.python.org/3/reference/compound_stmts.html",
	"https://docs.python.org/3/reference/toplevel_components.html",
	"https://docs.python.org/3/reference/grammar.html",
}

local function build_builtin_crawler()
	local source_rules = {
		Rule:new("regex", [[https://docs.python.org/3/reference/[a-z_]\+\.html]]),
	}

	local documentation_rules = {
		Rule:new("html_tag", "section"),
	}

	local name_rule = Rule:new("regex", [[<section id="\zs[^"]\+\ze"]])

	return CrawlerConfig:new(ROOT_URL, source_rules, documentation_rules, name_rule)
end

--- @class PythonAdapter: Adapter
local M = {}

function M:new()
	local instance = Adapter.new(self, "python")
	setmetatable(instance, { __index = self })
	return instance
end

function M:config_builtins()
	local crawler = build_builtin_crawler()

	for _, source in ipairs(REFERENCE_PAGES) do
		crawler:add_source(source)
	end

	crawler:fetch()
	Adapter.config_builtins(self, crawler)
end

return M
