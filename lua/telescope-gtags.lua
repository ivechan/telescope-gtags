function exec_global_symbol(symbol, extras)
	global_cmd = string.format('global --result="grep" %s "%s" 2>&1', extras, symbol)
	return exec_global(global_cmd)
end

function exec_global_current_file()
	local file = vim.call("expand", '%')
	local global_cmd = string.format('global --result="grep" -f "%s" 2>&1', file)
	return exec_global(global_cmd)
end

function exec_global(global_cmd)
	result = {}
	local f = io.popen(global_cmd)

	result.count = 0
	repeat
		local line = f:read("*l")
		if line then
			path, line_nr, text = string.match(line, "(.*):(%d+):(.*)")
			if path and line_nr then
				table.insert(result, { path = path, line_nr = tonumber(line_nr), text = text, raw = line })
				result.count = result.count + 1
			end
		end
	until line == nil

	f:close()
	return result
end

function global_definition(symbol)
	return exec_global_symbol(symbol, "-d")
end

function global_reference(symbol)
	return exec_global_symbol(symbol, "-r")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local make_entry = require("telescope.make_entry")
local loop = vim.loop
local api = vim.api

-- our picker function: gtags_picker
local gtags_picker = function(gtags_result)
	-- return if there is no result
	if gtags_result.count == 0 then
		print(string.format("E9999: Error gtags there is no symbol for %s", symbol))
		return
	end

	if gtags_result.count == 1 then
		vim.api.nvim_command(string.format(":edit +%d %s", gtags_result[1].line_nr, gtags_result[1].path))
		return
	end

	opts = {}
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

-- It's ok to update job_running without a lock
local M = { job_running = false }

function M.showDefinition()
	local current_word = vim.call("expand", "<cword>")
	if current_word == nil then
		return
	end
	local gtags_result = global_definition(current_word)
	gtags_picker(gtags_result)
end

function M.showReference()
	local current_word = vim.call("expand", "<cword>")
	if current_word == nil then
		return
	end
	gtags_result = global_reference(current_word)
	gtags_picker(gtags_result)
end

function M.showCurrentFileTags()
	gtags_picker(exec_global_current_file())
end

local function global_update()
	job_handle, pid = loop.spawn("global", {
		args = { "-u" },
	}, function(code, signal)
		if not code == 0 then
			print("ERROR: global -u return errors")
		end

		M.job_running = false
		job_handle:close()
	end)
end

function M.updateGtags()
	handle = loop.spawn("global", {
		args = { "--print", "dbpath" },
	}, function(code, signal)
		if code == 0 and M.job_running == false then
			M.job_running = true
			global_update()
		end
		handle:close()
	end)
end

function M.setAutoIncUpdate(enable)
	local async = require("plenary.async")
	if enable then
		vim.api.nvim_command("augroup AutoUpdateGtags")
		vim.api.nvim_command('autocmd BufWritePost * lua require("telescope-gtags").updateGtags()')
		vim.api.nvim_command("augroup END")
	end
end

local async = require("plenary.async")

return M
