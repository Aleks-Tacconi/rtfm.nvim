local Adapter = require("local-docs.abc-adapter.adapter")
local Rule = require("local-docs.abc-adapter.rule")

local ROOT_URL = "https://docs.python.org/3/reference/index.html"
local STDLIB_URL = "https://docs.python.org/3/library/index.html"

local function section_path(ctx)
	if not ctx.section_id then
		error(string.format("python adapter could not derive a path for '%s' section %d", ctx.source_url, ctx.section_index))
	end

	return string.format("%s/%s", ctx.source_name, ctx.section_id)
end

local function stdlib_symbol_path(ctx)
	if not ctx.section_id then
		error(string.format("python stdlib adapter could not derive a symbol path for '%s' section %d", ctx.source_url, ctx.section_index))
	end

	local prefix = ctx.source_name .. "."
	if ctx.section_id:sub(1, #prefix) ~= prefix then
		error(string.format("python stdlib section '%s' does not match source '%s'", ctx.section_id, ctx.source_name))
	end

	local parts = {}
	for part in ctx.section_id:sub(#prefix + 1):gmatch("[^.]+") do
		if #parts > 0 then
			part = part:gsub("^_+", "")
		end
		table.insert(parts, part)
	end

	local symbol_name = table.concat(parts, "__")
	return string.format("%s/%s", ctx.source_name:gsub("%.", "/"), symbol_name)
end

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
		path_mapper = section_path,
	},
	stdlib = {
		url = STDLIB_URL,
		source_rules = {
			Rule.regex([[<li class="toctree%-l2"><a class="reference internal" href="\zs[^"#]\+\.html\ze"]]),
		},
		documentation_rules = {
			Rule.selector(".py"),
		},
		path_mapper = stdlib_symbol_path,
	},
})
