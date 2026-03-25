local Adapter = require("local-docs.abc-adapter.adapter")
local Rule = require("local-docs.abc-adapter.rule")

local ROOT_URL = "https://docs.python.org/3/reference/index.html"

return Adapter.define({
	doc = "python",
	builtins = {
		url = ROOT_URL,
		seed_sources = {
			"introduction.html",
			"lexical_analysis.html",
			"datamodel.html",
			"executionmodel.html",
			"import.html",
			"expressions.html",
			"simple_stmts.html",
			"compound_stmts.html",
			"toplevel_components.html",
			"grammar.html",
		},
		discover_sources = false,
		documentation_rules = {
			Rule.tag("section"),
		},
		name_rule = Rule.regex([[<section id="\zs[^"]\+\ze"]]),
	},
})
