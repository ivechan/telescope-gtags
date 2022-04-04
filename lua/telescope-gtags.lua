function exec_global(symbol, extras)
	result = {}
	global_cmd = string.format('global --result="grep" %s "%s" 2>&1', extras, symbol)
	local f = io.popen(global_cmd)

	repeat
		local line = f:read("*l")
		if line then
			path, line_nr, text = string.match(line, "(.*):(%d+):(.*)")
			if path and line_nr then
				table.insert(result, { path = path, line_nr = tonumber(line_nr), text = text, raw = line })
			end
		end
	until line == nil

	f:close()
	return result
end

function global_definition(symbol)
	return exec_global(symbol, "-d")
end

function global_reference(symbol)
	return exec_global(symbol, "-r")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local make_entry = require("telescope.make_entry")

-- our picker function: gtags_picker
local gtags_picker = function(opts)
	opts = opts or {}
	if opts.symbol == nil then
		return
	end

	if opts.isref then
		gtags_result = global_reference(opts.symbol)
	else
		gtags_result = global_definition(opts.symbol)
	end

	-- return if there is no result
	if next(gtags_result) == nil then
		print(string.format("E9999: Error gtags there is no symbol for %s", symbol))
		return
	end

	-- print(to_string(gtags_result))
	pickers.new(opts, {
		prompt_title = "GNU Gtags",
		finder = finders.new_table({
			results = gtags_result,
			entry_maker = function(entry)
				return {
					value = entry.raw,
					ordinal = entry.raw,
					display = entry.raw,
					filename = entry.path,
					path = entry.path,
					lnum = entry.line_nr,
					start = entry.line_nr,
					col = 1,
				}
			end,
		}),
		previewer = conf.grep_previewer(opts),
		sorter = conf.generic_sorter(opts),
	}):find()
end

local M = {}

function M.showDefinition()
	local current_word = vim.call("expand", "<cword>")
	gtags_picker({ symbol = current_word, isref = false })
end

function M.showReference()
	local current_word = vim.call("expand", "<cword>")
	gtags_picker({ symbol = current_word, isref = true })
end

return M
