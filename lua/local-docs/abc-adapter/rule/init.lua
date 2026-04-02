local scanner = require("local-docs.abc-adapter.rule.scanner")

--- @alias rule_type "html_tag"|"html_tag_deep"|"class_id"|"heading_level"|"regex"

--- Applies a rule to the given html string, returning the results as an array of strings
local function __html_tag_rule(html, ctx)
	local target = ctx:lower()
	return scanner.collect_elements(html, function(node)
		return node.name_lower == target
	end)
end

--- Applies a class/id rule to the given html string, returning the results as an array of strings
local function __class_id_rule(html, ctx)
	local selector_type = ctx:sub(1, 1)
	local value = ctx:sub(2)

	if selector_type == "." then
		return scanner.collect_elements(html, function(node)
			local classes = scanner.extract_attr_value(node.opening_fragment, "class")
			if not classes then
				return false
			end

			for token in classes:gmatch("%S+") do
				if token == value then
					return true
				end
			end

			return false
		end)
	end

	return scanner.collect_elements(html, function(node)
		local id = scanner.extract_attr_value(node.opening_fragment, "id")
		return id == value
	end)
end

--- Filters fragments by first heading level.
--- @param html string
--- @param ctx string
--- @return string[]
local function __heading_level_rule(html, ctx)
	local heading = html:match("<h([1-6])[^>]*>")
	if heading == tostring(ctx) then
		return { html }
	end

	return {}
end

--- Applies a regex rule to the given html string, returning the results as an array of strings
local function __regex_rule(html, ctx)
	local results = {}
	local offset = 0

	while true do
		local match_start = vim.fn.match(html, ctx, offset)
		if match_start < 0 then
			break
		end

		local fragment = vim.fn.matchstr(html, ctx, offset)
		table.insert(results, fragment)

		if #fragment == 0 then
			offset = match_start + 1
		else
			offset = match_start + #fragment
		end
	end

	return results
end

--- @class Rule
--- @field type rule_type: Determines how the rule is applied to the html
--- @field ctx string: The context of the rule, either the html tag to search for,
---                    the class/id to search for, or the regex pattern to apply
local M = {}

--- @param type rule_type: Determines how the rule is applied to the html
--- @param ctx string: The context of the rule, either the html tag to search for,
---                    the class/id to search for, or the regex pattern to apply
function M:new(type, ctx)
	local instance = { type = type, ctx = ctx }
	setmetatable(instance, { __index = self })
	return instance
end

--- Creates a rule that matches full HTML elements by tag name.
--- @param tag string
--- @return Rule
function M.tag(tag)
	return M:new("html_tag", tag)
end

--- Creates a rule that matches full HTML elements by tag name, including nested matches.
--- @param tag string
--- @return Rule
function M.deep_tag(tag)
	return M:new("html_tag_deep", tag)
end

--- Creates a rule that matches full HTML elements by .class or #id selector.
--- @param selector string
--- @return Rule
function M.selector(selector)
	return M:new("class_id", selector)
end

--- Creates a rule that keeps fragments whose first heading is at the given level.
--- @param level integer
--- @return Rule
function M.heading_level(level)
	return M:new("heading_level", tostring(level))
end

--- Creates a rule that matches all expressions for a regex pattern.
--- @param pattern string
--- @return Rule
function M.regex(pattern)
	return M:new("regex", pattern)
end

--- @param html string: the html to apply the rule to
--- @return string[]: strings extracted from the html according to the rule
function M:apply(html)
	if self.type == "html_tag" then
		return __html_tag_rule(html, self.ctx)
	end
	if self.type == "html_tag_deep" then
		local target = self.ctx:lower()
		return scanner.collect_elements_deep(html, function(node)
			return node.name_lower == target
		end)
	end
	if self.type == "class_id" then
		return __class_id_rule(html, self.ctx)
	end
	if self.type == "heading_level" then
		return __heading_level_rule(html, self.ctx)
	end
	return __regex_rule(html, self.ctx)
end

return M
