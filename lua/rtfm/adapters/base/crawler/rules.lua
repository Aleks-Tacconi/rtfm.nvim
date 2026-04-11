local M = {}

--- Applies a chain of rules to an HTML fragment.
--- @param html string
--- @param rules table[]
--- @return string[]
function M.apply(html, rules)
	local results = { html }

	for _, rule in ipairs(rules) do
		local next_results = {}
		for _, fragment in ipairs(results) do
			vim.list_extend(next_results, rule:apply(fragment))
		end
		results = next_results
	end

	return results
end

--- Applies a rule chain and raises on failure.
--- @param html string
--- @param rules table[]
--- @return string[]
function M.apply_sync(html, rules)
	local ok, result = pcall(M.apply, html, rules)
	if not ok then
		error(result)
	end

	return result
end

return M
