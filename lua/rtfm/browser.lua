local Adapter = require("rtfm.abc-adapter.adapter")
local Index = require("rtfm.index")
local Viewer = require("rtfm.viewer")

local M = {}

--- Returns the 1-based index for an entry table.
--- @param entries table[]
--- @param target table
--- @return integer
local function entry_index(entries, target)
	for index, entry in ipairs(entries) do
		if entry == target then
			return index
		end
	end

	error("selected doc was not found in the ordered index")
end

--- Returns Telescope modules or raises a clear error.
--- @return table
local function telescope_modules()
	local ok, pickers = pcall(require, "telescope.pickers")
	if not ok then
		error("telescope.nvim is required for :RtfmBrowse")
	end

	return {
		pickers = pickers,
		finders = require("telescope.finders"),
		actions = require("telescope.actions"),
		action_state = require("telescope.actions.state"),
		conf = require("telescope.config").values,
	}
end

--- Opens a Telescope picker with a static table of entries.
--- @param title string
--- @param entries table[]
--- @param display_key string
--- @param on_select fun(selection: table)
--- @return nil
local function open_picker(title, entries, display_key, on_select)
	if #entries == 0 then
		error(string.format("No entries available for %s", title))
	end

	local telescope = telescope_modules()
	telescope.pickers
		.new({}, {
			prompt_title = title,
			finder = telescope.finders.new_table({
				results = entries,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry[display_key],
						ordinal = entry[display_key],
					}
				end,
			}),
			sorter = telescope.conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr)
				telescope.actions.select_default:replace(function()
					local selection = telescope.action_state.get_selected_entry()
					telescope.actions.close(prompt_bufnr)
					on_select(selection.value)
				end)
				return true
			end,
		})
		:find()
end

--- Opens the final doc picker for a source group.
--- @param context table
--- @param source table
--- @return nil
local function pick_doc(context, source)
	local docs = {}
	for index, entry in ipairs(source.entries) do
		table.insert(docs, {
			label = string.format("%d. %s", entry.ordinal, entry.title),
			index = index,
			entry = entry,
		})
	end

	open_picker(string.format("RTFM Docs: %s", source.name), docs, "label", function(selection)
		local ordered_index = entry_index(context.entries, selection.entry)
		Viewer.open({ adapter = context.adapter, scope = context.scope }, context.entries, ordered_index)
	end)
end

--- Opens the source picker for an adapter scope.
--- @param adapter string
--- @param scope table
--- @return nil
local function pick_source(adapter, scope)
	local index = Index.load_scope_index(adapter, scope.dir)
	local sources = {}
	for _, source in ipairs(Index.group_sources(index.entries)) do
		table.insert(sources, {
			label = string.format("%s (%d)", source.name, #source.entries),
			name = source.name,
			entries = source.entries,
		})
	end

	open_picker(string.format("RTFM Sources: %s/%s", adapter, scope.dir), sources, "label", function(selection)
		pick_doc(index, selection)
	end)
end

--- Opens the scope picker for an adapter.
--- @param adapter_name string
--- @param adapters table<string, string>
--- @return nil
local function pick_scope(adapter_name, adapters)
	local adapter = require(adapters[adapter_name]):new()
	local scopes = Index.list_scopes(adapter, Adapter.scopes_for(adapter))
	open_picker(string.format("RTFM Scopes: %s", adapter_name), scopes, "label", function(selection)
		pick_source(adapter_name, selection)
	end)
end

--- Opens the top-level adapter picker.
--- @param adapters table<string, string>
--- @return nil
function M.browse(adapters)
	local names = {}
	for _, name in ipairs(Index.list_adapters(adapters)) do
		table.insert(names, { label = name, name = name })
	end

	open_picker("RTFM Adapters", names, "label", function(selection)
		pick_scope(selection.name, adapters)
	end)
end

return M
