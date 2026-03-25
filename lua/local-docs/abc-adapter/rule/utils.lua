local M = {}

--- Applies a chain of rules to a given html string, returning the results of the final rule in the chain
--- @param html string: The html to apply the rules to
--- @param rules Rule[]: The chain of rules to apply to the html, in order
M.apply_rule_chain = function(html, rules)
	local results = { html }

	for _, rule in ipairs(rules) do
		local new_results = {}
		for _, fragment in ipairs(results) do
			local applied = rule:apply(fragment)
			vim.list_extend(new_results, applied)
		end
		results = new_results
	end

	return results
end

return M
