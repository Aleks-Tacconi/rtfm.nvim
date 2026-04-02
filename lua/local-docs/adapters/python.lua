local Adapter = require("local-docs.abc-adapter.adapter")
local Rule = require("local-docs.abc-adapter.rule")

local ROOT_URL = "https://docs.python.org/3/reference/index.html"
local STDLIB_URL = "https://docs.python.org/3/library/index.html"

return Adapter.define({
	doc = "python",
	builtins = {
		url = ROOT_URL,
		seed_sources = {
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
		},
		documentation_rules = {
			Rule.tag("section"),
		},
		name_rule = Rule.regex([[<section id="\zs[^"]\+\ze"]]),
	},
	stdlib = {
		url = STDLIB_URL,
		source_rules = {
			Rule.regex([[<li class="toctree%-l2"><a class="reference internal" href="\zs[^"#]\+\.html\ze"]]),
		},
		documentation_rules = {
			Rule.selector(".py"),
		},
		name_rule = Rule.regex([[ id="\zs[^"]\+\ze"]]),
	},
})
