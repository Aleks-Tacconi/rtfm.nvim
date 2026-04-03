local M = {}

local VALID_KINDS = {
	language = true,
	framework = true,
}

local function validate_rules(scope_name, key, rules)
	if type(rules) ~= "table" then
		error(string.format("adapter scope '%s' field '%s' must be a list", scope_name, key))
	end
end

local function validate_scope(scope_name, scope)
	if type(scope) ~= "table" then
		error(string.format("adapter scope '%s' must be a table", scope_name))
	end

	if type(scope.url) ~= "string" or scope.url == "" then
		error(string.format("adapter scope '%s' requires a non-empty 'url'", scope_name))
	end

	if type(scope.name_rule) ~= "table" then
		error(string.format("adapter scope '%s' requires a 'name_rule'", scope_name))
	end

	validate_rules(scope_name, "documentation_rules", scope.documentation_rules)

	if scope.seed_sources ~= nil then
		validate_rules(scope_name, "seed_sources", scope.seed_sources)
	end

	if scope.source_rules ~= nil then
		validate_rules(scope_name, "source_rules", scope.source_rules)
	end

	if scope.source_filter ~= nil and type(scope.source_filter) ~= "function" then
		error(string.format("adapter scope '%s' field 'source_filter' must be a function", scope_name))
	end

	if scope.path_mapper ~= nil and type(scope.path_mapper) ~= "function" then
		error(string.format("adapter scope '%s' field 'path_mapper' must be a function", scope_name))
	end

	if scope.request_delay_ms ~= nil and (type(scope.request_delay_ms) ~= "number" or scope.request_delay_ms < 0) then
		error(string.format("adapter scope '%s' field 'request_delay_ms' must be a non-negative number", scope_name))
	end

	if scope.retry_failed_fetches ~= nil and type(scope.retry_failed_fetches) ~= "boolean" then
		error(string.format("adapter scope '%s' field 'retry_failed_fetches' must be a boolean", scope_name))
	end

	if scope.retry_delay_ms ~= nil and (type(scope.retry_delay_ms) ~= "number" or scope.retry_delay_ms < 0) then
		error(string.format("adapter scope '%s' field 'retry_delay_ms' must be a non-negative number", scope_name))
	end

	if #scope.documentation_rules == 0 then
		error(string.format("adapter scope '%s' requires at least one documentation rule", scope_name))
	end

	if scope.url:match("^https?://") == nil then
		error(string.format("adapter scope '%s' requires an absolute http(s) 'url'", scope_name))
	end

	if scope.seed_sources ~= nil then
		for index, source in ipairs(scope.seed_sources) do
			if type(source) ~= "string" or source == "" then
				error(string.format("adapter scope '%s' seed source %d must be a non-empty string", scope_name, index))
			end
		end
	end

	return true
end

function M.validate(spec)
	if type(spec) ~= "table" then
		error("adapter spec must be a table")
	end

	if type(spec.kind) ~= "string" or spec.kind == "" then
		error("adapter spec requires a non-empty 'kind'")
	end

	if not VALID_KINDS[spec.kind] then
		error(string.format("adapter spec kind must be 'language' or 'framework', got '%s'", spec.kind))
	end

	if type(spec.doc) ~= "string" or spec.doc == "" then
		error("adapter spec requires a non-empty 'doc'")
	end

	if spec.misc ~= nil then
		error("adapter scope 'misc' was removed; use kind='framework' with an 'api' scope")
	end

	if spec.kind == "language" then
		if spec.api ~= nil then
			error("language adapters cannot define an 'api' scope")
		end

		if spec.builtins == nil and spec.stdlib == nil then
			error("language adapters require at least one of: builtins, stdlib")
		end

		if spec.builtins ~= nil then
			validate_scope("builtins", spec.builtins)
		end

		if spec.stdlib ~= nil then
			validate_scope("stdlib", spec.stdlib)
		end

		return true
	end

	if spec.builtins ~= nil or spec.stdlib ~= nil then
		error("framework adapters can only define an 'api' scope")
	end

	if spec.api == nil then
		error("framework adapters require an 'api' scope")
	end

	validate_scope("api", spec.api)

	return true
end

return M
