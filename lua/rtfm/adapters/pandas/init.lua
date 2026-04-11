local Adapter = require("rtfm.adapters.base.adapter")
local Rule = require("rtfm.adapters.base.rule")

local API_URL = "https://pandas.pydata.org/docs/reference/index.html"
local API_SEED_SOURCES = require("rtfm.adapters.pandas.seed_sources")

--- Returns the output path for a pandas API page.
--- @param ctx table
--- @return string
local function api_path(ctx)
	local source_key = ctx.source_name:gsub("^pandas%.", "")
	local parts = vim.split(source_key, ".", { plain = true, trimempty = true })
	if #parts == 0 then
		return string.format("pandas/general/%s", ctx.normalized_name)
	end

	local section = parts[1]:lower()
	local file_parts = {}
	if #parts == 1 then
		if section == parts[1] then
			section = "general"
		end
		table.insert(file_parts, parts[1]:lower())
	else
		for index = 2, #parts do
			table.insert(file_parts, parts[index]:lower())
		end
	end

	return string.format("pandas/%s/%s", section, table.concat(file_parts, "_"))
end

return Adapter.define({
	kind = "framework",
	doc = "pandas",
	api = {
		url = API_URL,
		seed_sources = API_SEED_SOURCES,
		path_mapper = api_path,
		documentation_rules = {
			Rule.deep_tag("section"),
			Rule.heading_level(1),
		},
		name_rule = Rule.regex([[ id="\zspandas\.[^"]\+\ze"]]),
	},
})
