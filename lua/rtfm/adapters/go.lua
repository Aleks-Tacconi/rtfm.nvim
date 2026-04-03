local Adapter = require("rtfm.abc-adapter.adapter")
local Rule = require("rtfm.abc-adapter.rule")

local BUILTINS_URL = "https://pkg.go.dev/builtin"
local STDLIB_URL = "https://docs-go.hexacode.org/pkg/"
local DOC_SECTION_PATTERN =
	[[<h2[^>]*id="[^"]\+"[^>]*>\_.\{-}\ze\(<h2[^>]*id="\|<div id="footer"\|Build version\)]]

local function is_public_stdlib_source(url)
	local path = url:match("^https?://docs%-go%.hexacode%.org/pkg/(.+)/$") or ""
	return path ~= ""
		and path:match("^[a-z0-9_/-]+$")
		and not path:match("^pkg/")
		and not path:match("^builtin$")
end

return Adapter.define({
	doc = "go",
	builtins = {
		url = BUILTINS_URL,
		seed_sources = { BUILTINS_URL },
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
		documentation_rules = {
			Rule.regex(DOC_SECTION_PATTERN),
		},
		name_rule = Rule.regex([[id="\zs[^"]\+\ze"]]),
	},
})
