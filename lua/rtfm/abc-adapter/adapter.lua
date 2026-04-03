local CrawlerConfig = require("rtfm.abc-adapter.crawler-config")
local Contract = require("rtfm.abc-adapter.contract")
local utils = require("rtfm.utils")

--- @class Adapter
--- Abstract base adapter class, defines the interface for pulling doc specifications
--- and storing them in language/option/(data_structure|type|function).md
--- @field doc string: The language / framework the documentation being pulled from is for, used for display purposes
local M = {}

M.SCOPES = {
	{ spec_key = "builtins", method = "config_builtins", dir = "builtin" },
	{ spec_key = "stdlib", method = "config_stdlib", dir = "stdlib" },
	{ spec_key = "misc", method = "config_misc", dir = "misc" },
}

--- Constructs a new adapter instance
--- @param doc string: The language / framework the documentation being pulled from is for, used for display purposes
function M:new(doc)
	local instance = { doc = doc, abstract = false }
	setmetatable(instance, { __index = self })
	return instance
end

local function fail_with_cleanup(temp_path, err, done)
	if temp_path then
		utils.safe_delete(temp_path)
	end

	done(false, err)
end

local function fail_with_cleanup_sync(temp_path, err)
	if temp_path then
		utils.safe_delete(temp_path)
	end

	error(err)
end

local function commit_scope(temp_path, target_path, done)
	local backup_path = target_path .. ".bak"
	utils.safe_delete(backup_path)

	local had_target = vim.fn.isdirectory(target_path) == 1
	if had_target then
		local backup_ok, backup_err = utils.safe_rename(target_path, backup_path)
		if not backup_ok then
			fail_with_cleanup(temp_path, backup_err, done)
			return
		end
	end

	local rename_ok, rename_err = utils.safe_rename(temp_path, target_path)
	if rename_ok then
		utils.safe_delete(backup_path)
		done(true)
		return
	end

	if had_target then
		utils.safe_rename(backup_path, target_path)
	end
	fail_with_cleanup(temp_path, rename_err, done)
end

local function commit_scope_sync(temp_path, target_path)
	local backup_path = target_path .. ".bak"
	utils.safe_delete(backup_path)

	local had_target = vim.fn.isdirectory(target_path) == 1
	if had_target then
		local backup_ok, backup_err = utils.safe_rename(target_path, backup_path)
		if not backup_ok then
			fail_with_cleanup_sync(temp_path, backup_err)
		end
	end

	local rename_ok, rename_err = utils.safe_rename(temp_path, target_path)
	if rename_ok then
		utils.safe_delete(backup_path)
		return
	end

	if had_target then
		utils.safe_rename(backup_path, target_path)
	end
	fail_with_cleanup_sync(temp_path, rename_err)
end

--- Runs crawler extraction for a given output scope directory.
--- @param scope_dir string
--- @param crawler_spec table
function M:_run_scope(scope_dir, crawler_spec, done)
	local crawler = CrawlerConfig:new(crawler_spec)
	local parent_path = utils.data_dir .. self.doc
	local target_path = parent_path .. "/" .. scope_dir
	local temp_path, temp_err = utils.make_temp_dir(parent_path, scope_dir)
	if not temp_path then
		done(false, temp_err)
		return
	end

	crawler:fetch(function(fetch_ok, fetch_err)
		if not fetch_ok then
			fail_with_cleanup(temp_path, fetch_err, done)
			return
		end

		crawler:fetch_all_documentation(temp_path, function(doc_ok, doc_err)
			if not doc_ok then
				fail_with_cleanup(temp_path, doc_err, done)
				return
			end

			commit_scope(temp_path, target_path, done)
		end)
	end)
end

--- Runs crawler extraction synchronously for a given output scope directory.
--- @param scope_dir string
--- @param crawler_spec table
--- @return nil
function M:_run_scope_sync(scope_dir, crawler_spec)
	local crawler = CrawlerConfig:new(crawler_spec)
	local parent_path = utils.data_dir .. self.doc
	local target_path = parent_path .. "/" .. scope_dir
	local temp_path, temp_err = utils.make_temp_dir(parent_path, scope_dir)
	if not temp_path then
		error(temp_err)
	end

	local ok, err = pcall(function()
		crawler:fetch_sync()
		crawler:fetch_all_documentation_sync(temp_path)
		commit_scope_sync(temp_path, target_path)
	end)

	if not ok then
		fail_with_cleanup_sync(temp_path, err)
	end
end

--- Defines an adapter for pulling builtin functions from official language
--- doc specifications and storing them in language/builtin/(type|function).md
--- @param crawler_spec table: declarative crawler spec
function M:config_builtins(crawler_spec, done)
	self:_run_scope("builtin", crawler_spec, done)
end

--- @param crawler_spec table
function M:config_builtins_sync(crawler_spec)
	self:_run_scope_sync("builtin", crawler_spec)
end

--- @param crawler_spec table
function M:config_stdlib(crawler_spec, done)
	self:_run_scope("stdlib", crawler_spec, done)
end

--- @param crawler_spec table
function M:config_stdlib_sync(crawler_spec)
	self:_run_scope_sync("stdlib", crawler_spec)
end

--- @param crawler_spec table
function M:config_misc(crawler_spec, done)
	self:_run_scope("misc", crawler_spec, done)
end

--- @param crawler_spec table
function M:config_misc_sync(crawler_spec)
	self:_run_scope_sync("misc", crawler_spec)
end

--- @class AdapterSpec
--- @field doc string
--- @field builtins table|nil
--- @field stdlib table|nil
--- @field misc table|nil

--- Defines a declarative adapter with preconfigured crawler specs.
--- @param spec AdapterSpec
--- @return Adapter
function M.define(spec)
	Contract.validate(spec)

	local adapter = {
		doc = spec.doc,
		spec = spec,
	}
	setmetatable(adapter, { __index = M })

	function adapter:new()
		return M.new(self, self.doc)
	end

	for _, scope in ipairs(M.SCOPES) do
		if spec[scope.spec_key] then
			local scope_key = scope.spec_key
			local scope_dir = scope.dir
			adapter[scope.method] = function(self, done)
				self:_run_scope(scope_dir, self.spec[scope_key], done)
			end
			adapter[scope.method .. "_sync"] = function(self)
				self:_run_scope_sync(scope_dir, self.spec[scope_key])
			end
		end
	end

	return adapter
end

return M
