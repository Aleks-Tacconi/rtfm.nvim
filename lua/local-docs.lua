local M = {}

M.setup = function()
	local docs_path = vim.fn.stdpath("data") .. "/local-docs"

	if vim.fn.isdirectory(docs_path) == 0 then
		vim.fn.mkdir(docs_path, "p")
	end
end

return M
