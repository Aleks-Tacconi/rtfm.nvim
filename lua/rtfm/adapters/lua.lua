local Adapter = require("rtfm.abc-adapter.adapter")
local Rule = require("rtfm.abc-adapter.rule")

local MANUAL_URL = "https://www.lua.org/manual/5.4/manual.html"
local BUILTIN_SECTION_PATTERN = [[<h2>6\.1\_.\{-}</h2>\_.\{-}\ze<h2>6\.2]]
local ENTRY_PATTERN = [[<hr><h3><a name="pdf-[^"]\+"><code>[^<]\+</code></a></h3>
\_.\{-}\ze\(<hr><h3><a name="pdf-\|<h[23]>[0-9]\|</body>\|\%$\)]]
local STDLIB_ENTRY_PATTERN = [[<hr><h3><a name="pdf-
\%(require\|coroutine\.[^"]\+\|package\.[^"]\+\|string\.[^"]\+\|utf8\.[^"]\+
\|table\.[^"]\+\|math\.[^"]\+\|io\.[^"]\+\|os\.[^"]\+\|debug\.[^"]\+
\|file:[^"]\+\)"><code>[^<]\+</code></a></h3>
\_.\{-}\ze\(<hr><h3><a name="pdf-\|<h[23]>[0-9]\|</body>\|\%$\)]]

--- Returns the builtin output path grouped under globals.
--- @param ctx table
--- @return string
local function builtin_path(ctx)
	return string.format("globals/%s", ctx.normalized_name)
end

--- Returns the stdlib output path grouped by library.
--- @param ctx table
--- @return string
local function stdlib_path(ctx)
	local section_name = ctx.section_name or ""
	if section_name == "require" then
		return "package/require"
	end

	if section_name:match("^file:") then
		local item = section_name:match("^file:(.+)$") or ctx.normalized_name
		return string.format("io/file_%s", item)
	end

	local library, item = section_name:match("^([^.]+)%.(.+)$")
	if library and item then
		return string.format("%s/%s", library, item)
	end

	return string.format("other/%s", ctx.normalized_name)
end

return Adapter.define({
	kind = "language",
	doc = "lua",
	builtins = {
		url = MANUAL_URL,
		seed_sources = { MANUAL_URL },
		path_mapper = builtin_path,
		documentation_rules = {
			Rule.regex(BUILTIN_SECTION_PATTERN),
			Rule.regex(ENTRY_PATTERN),
		},
		name_rule = Rule.regex([[name="pdf-\zs[^"]\+\ze"]]),
	},
	stdlib = {
		url = MANUAL_URL,
		seed_sources = { MANUAL_URL },
		path_mapper = stdlib_path,
		documentation_rules = {
			Rule.regex(STDLIB_ENTRY_PATTERN),
		},
		name_rule = Rule.regex([[name="pdf-\zs[^"]\+\ze"]]),
	},
})
