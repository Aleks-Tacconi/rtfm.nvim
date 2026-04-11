local M = {}

M.defaults = {
	keymaps = {
		manage = "<leader>rm",
		browse = "<leader>rb",
	},
	viewer = {
		keymaps = {
			prev = "[d",
			next = "]d",
		},
	},
}

--- Returns the merged plugin configuration.
--- @param current table|nil
--- @param opts table|nil
--- @return table
function M.merge(current, opts)
	opts = opts or {}
	return vim.tbl_deep_extend("force", current or M.defaults, {
		keymaps = opts.keymaps or {},
		viewer = opts.viewer or {},
	})
end

return M
