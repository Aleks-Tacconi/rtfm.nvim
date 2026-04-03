local Adapter = require("rtfm.abc-adapter.adapter")
local Rule = require("rtfm.abc-adapter.rule")

local BUILTINS_URL = "https://docs-go.hexacode.org/pkg/builtin/"
local STDLIB_URL = "https://docs-go.hexacode.org/pkg/"
local DOC_SECTION_PATTERN = [[<h2[^>]*id="[^"]\+"[^>]*>\_.\{-}\ze\(<h2[^>]*id="\|<div id="footer"\|Build version\)]]

--- Returns the stdlib output path without the upstream pkg/ prefix.
--- @param ctx table
--- @return string
local function stdlib_path(ctx)
	local source_key = ctx.source_name:gsub("^pkg/", "")
	return string.format("%s/%s", source_key, ctx.normalized_name)
end

--- Returns the builtin output path as a flat symbol file.
--- @param ctx table
--- @return string
local function builtin_group(ctx)
	if ctx.section_id == "pkg-constants" then
		return "constants"
	end

	if ctx.section_id == "pkg-variables" then
		return "variables"
	end

	local heading = (ctx.heading_text or ""):lower()
	if heading:match("^type%s") then
		return "types"
	end

	return "functions"
end

--- Returns the builtin output path grouped by section kind.
--- @param ctx table
--- @return string
local function builtin_path(ctx)
	return string.format("%s/%s", builtin_group(ctx), ctx.normalized_name)
end

local function is_public_stdlib_source(url)
	local path = url:match("^https?://docs%-go%.hexacode%.org/pkg/(.+)/$") or ""
	return path ~= "" and path:match("^[a-z0-9_/-]+$") and not path:match("^pkg/") and not path:match("^builtin$")
end

return Adapter.define({
	kind = "language",
	doc = "go",
	builtins = {
		url = BUILTINS_URL,
		seed_sources = { BUILTINS_URL },
		path_mapper = builtin_path,
		documentation_rules = {
			Rule.regex(DOC_SECTION_PATTERN),
		},
		name_rule = Rule.regex([[id="\zs[^"]\+\ze"]]),
	},
	stdlib = {
		url = STDLIB_URL,
		source_rules = {
			Rule.regex([[href="\zs[a-z0-9_/]\+/\ze"]]),
		},
		source_filter = is_public_stdlib_source,
		path_mapper = stdlib_path,
		documentation_rules = {
			Rule.regex(DOC_SECTION_PATTERN),
		},
		name_rule = Rule.regex([[id="\zs[^"]\+\ze"]]),
	},
})
