local Adapter = require("rtfm.abc-adapter.adapter")
local Rule = require("rtfm.abc-adapter.rule")

local BUILTINS_URL = "https://pkg.go.dev/builtin"
local STDLIB_URL = "https://pkg.go.dev/std"
local OVERVIEW_SECTION_PATTERN = [[<section class="Documentation-overview">\_.\{-}</section>]]

local function is_public_stdlib_source(url)
	local path = url:match("^https?://pkg%.go%.dev/(.+)$") or ""
	return path ~= ""
		and not path:match("^builtin$")
		and not path:match("^std$")
		and not path:match("^cmd/")
		and not path:match("^internal/")
		and not path:match("/internal/")
		and not path:match("test")
end

return Adapter.define({
	doc = "go",
	builtins = {
		url = BUILTINS_URL,
		seed_sources = { BUILTINS_URL },
		documentation_rules = {
			Rule.selector(".Documentation-content"),
			Rule.regex(OVERVIEW_SECTION_PATTERN),
		},
		name_rule = Rule.regex([[id="\zs[^"]\+\ze"]]),
	},
	stdlib = {
		url = STDLIB_URL,
		request_delay_ms = 1200,
		retry_failed_fetches = true,
		retry_delay_ms = 5000,
		source_rules = {
			Rule.regex([[href="\zs/\%(builtin\|std\|cmd/\)\@![^"?#@]\+\ze@go[0-9][^"]*"]]),
		},
		source_filter = is_public_stdlib_source,
		documentation_rules = {
			Rule.selector(".Documentation-content"),
			Rule.regex(OVERVIEW_SECTION_PATTERN),
		},
		name_rule = Rule.regex([[id="\zs[^"]\+\ze"]]),
	},
})
