local M = {}

--- A set of HTML tags that are considered void elements,
--- meaning they do not have a closing tag and cannot contain content
M.VOID_TAGS = {
	area = true,
	base = true,
	br = true,
	col = true,
	embed = true,
	hr = true,
	img = true,
	input = true,
	link = true,
	meta = true,
	param = true,
	source = true,
	track = true,
	wbr = true,
}

--- Finds the index of the closing '>' for an opening tag in the given html string,
--- starting from the specified index of the opening '<'.
--- @param html string: The HTML string to search through
--- @param open_start integer: The index of the opening '<' of the tag to find the closing '>' for
--- @return integer|nil: The index of the closing '>' character, or nil if not found
function M.find_tag_end(html, open_start)
	local i = open_start + 1
	local quote = nil

	while i <= #html do
		local ch = html:sub(i, i)
		if quote then
			if ch == quote then
				quote = nil
			end
		elseif ch == '"' or ch == "'" then
			quote = ch
		elseif ch == ">" then
			return i
		end

		i = i + 1
	end

	return nil
end

--- Parses an opening tag from the given html string starting at the specified index,
--- and returns a table containing the tag's name, position, and other relevant information.
--- @param html string: The HTML string to parse
--- @open_start integer: The index of the opening '<' of the tag to parse
--- @return table|nil: A table containing the tag's name, position, and other relevant information,
function M.parse_opening_tag(html, open_start)
	local open_end = M.find_tag_end(html, open_start)
	if not open_end then
		return nil
	end

	local inner = html:sub(open_start + 1, open_end - 1)
	local first = inner:sub(1, 1)
	if first == "/" or first == "!" or first == "?" then
		return nil
	end

	local tag_name = inner:match("^%s*([%w:_-]+)")
	if not tag_name then
		return nil
	end

	local opening_fragment = html:sub(open_start, open_end)
	local self_closing = opening_fragment:match("/%s*>$") ~= nil

	return {
		name = tag_name,
		name_lower = tag_name:lower(),
		open_start = open_start,
		open_end = open_end,
		opening_fragment = opening_fragment,
		self_closing = self_closing,
	}
end

--- Extracts the value of a specified attribute from an opening tag fragment.
--- @param opening_fragment string: The string containing the opening tag fragment to extract the attribute value from
--- @param attr string: The name of the attribute to extract the value for
--- @return string|nil: The value of the specified attribute, or nil if the attribute is not found
function M.extract_attr_value(opening_fragment, attr)
	local value = opening_fragment:match(attr .. '%s*=%s*"([^"]*)"')
	if value then
		return value
	end

	value = opening_fragment:match(attr .. "%s*=%s*'([^']*)'")
	if value then
		return value
	end

	return opening_fragment:match(attr .. "%s*=%s*([^%s\"'`=<>]+)")
end

--- Finds the matching closing tag for a given opening tag in the html string, starting from a specified position.
--- @param html string: The HTML string to search through
--- @param tag_name string: The name of the tag to find the matching closing tag for
--- @param from_pos integer: The index to start searching for the matching closing tag from,
---                          typically just after the opening tag
--- @return integer|nil, integer|nil: The indices of the opening '<' and closing '>' of the
---                               matching closing tag, or nil if not found
function M.find_matching_close(html, tag_name, from_pos)
	local target = tag_name:lower()
	local depth = 1
	local pos = from_pos

	while pos <= #html do
		local open_start = html:find("<", pos, true)
		if not open_start then
			return nil
		end

		local open_end = M.find_tag_end(html, open_start)
		if not open_end then
			return nil
		end

		local inner = html:sub(open_start + 1, open_end - 1)
		local closing_name = inner:match("^%s*/%s*([%w:_-]+)")
		if closing_name then
			if closing_name:lower() == target then
				depth = depth - 1
				if depth == 0 then
					return open_start, open_end
				end
			end
		else
			local nested = M.parse_opening_tag(html, open_start)
			if nested and nested.name_lower == target and not nested.self_closing and not M.VOID_TAGS[target] then
				depth = depth + 1
			end
		end

		pos = open_end + 1
	end

	return nil
end

--- Collects elements from the given html string that satisfy the provided predicate function,
--- and returns them as an array of strings. The predicate function is called with a table containing
--- information about each opening tag node, and should return true for nodes that should be collected.
--- @param html string: The HTML string to collect elements from
--- @param predicate function: A function that takes a table containing information about an opening tag node,
--- @return string[]: An array of strings representing the collected elements that satisfy the predicate function
function M.collect_elements(html, predicate)
	local results = {}
	local pos = 1

	while pos <= #html do
		local open_start = html:find("<", pos, true)
		if not open_start then
			break
		end

		local node = M.parse_opening_tag(html, open_start)
		if not node then
			pos = open_start + 1
		else
			if predicate(node) then
				if node.self_closing or M.VOID_TAGS[node.name_lower] then
					table.insert(results, node.opening_fragment)
					pos = node.open_end + 1
				else
					local close_start, close_end = M.find_matching_close(html, node.name, node.open_end + 1)
					if close_start and close_end then
						table.insert(results, html:sub(node.open_start, close_end))
						pos = close_end + 1
					else
						pos = node.open_end + 1
					end
				end
			else
				pos = node.open_end + 1
			end
		end
	end

	return results
end

return M
