local Adapter = require("rtfm.abc-adapter.adapter")
local Rule = require("rtfm.abc-adapter.rule")

local BUILTINS_URL = "https://pkg.go.dev/builtin"
local STDLIB_URL = "https://pkg.go.dev/std"
local DOC_SECTION_PATTERN = [[<section class="Documentation-overview">\_.\{-}</section>
	\|<section class="Documentation-index">\_.\{-}</section>
	\|<h3[^>]*id="pkg-[^"]\+"[^>]*>\_.\{-}\ze\(<h3[^>]*id="pkg-[^"]\+"\|</div>\_s*$\)]]

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
			Rule.regex(DOC_SECTION_PATTERN),
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
			Rule.regex(DOC_SECTION_PATTERN),
		},
		name_rule = Rule.regex([[id="\zs[^"]\+\ze"]]),
	},
})
