local Adapter = require("rtfm.abc-adapter.adapter")
local Rule = require("rtfm.abc-adapter.rule")

local BUILTINS_URL = "https://pkg.go.dev/builtin"
local STDLIB_URL = "https://pkg.go.dev/std"

local DOC_SECTION_PATTERN = [[<section class="Documentation-overview">\_.\{-}</section>\|<section class="Documentation-index">\_.\{-}</section>\|<h3[^>]*id="pkg-[^"]\+"[^>]*>\_.\{-}\ze\(<h3[^>]*id="pkg-[^"]\+"\|</div>\_s*$\)]]

return Adapter.define({
	doc = "go",
	builtins = {
		url = BUILTINS_URL,
		seed_sources = { BUILTINS_URL },
		documentation_rules = {
			Rule.selector(".Documentation-content"),
			Rule.regex(DOC_SECTION_PATTERN),
		},
		name_rule = Rule.regex([[id="\zs[^"]\+\ze"]]),
	},
	stdlib = {
		url = STDLIB_URL,
		source_rules = {
			Rule.regex([[href="\zs/\%(builtin\|std\|cmd/\)\@![^"?#@]\+\ze@go[0-9][^"]*"]]),
		},
		documentation_rules = {
			Rule.selector(".Documentation-content"),
			Rule.regex(DOC_SECTION_PATTERN),
		},
		name_rule = Rule.regex([[id="\zs[^"]\+\ze"]]),
	},
})
