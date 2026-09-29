local M = {}
local cursor_marker = "{{_cursor_}}"
local cursor_token = "\001template_cursor\002"

-- The pinned plugin exposes registration but no synchronous render API. Reuse
-- its expression engine without its asynchronous, current-window-dependent IO.
local function engine()
	local register = require("template").register
	for index = 1, 20 do
		local name, value = debug.getupvalue(register, index)
		if not name then
			break
		end
		if
			name == "renderer"
			and type(value) == "table"
			and type(value.render_line) == "function"
			and type(value.expression_replacer_map) == "table"
		then
			return value
		end
	end
	error("Motor do template.nvim incompatível; revise o adaptador antes de atualizar o plugin.")
end

function M.render(item, context)
	local renderer = engine()
	local data = table.concat(vim.fn.readfile(item.file, "b"), "\n"):gsub("\r\n?", "\n")
	local source = vim.split(data, "\n", { plain = true })
	if source[#source] == "" then
		table.remove(source)
	end
	if source[1] and source[1]:match("^;;%s+%S+$") then
		table.remove(source, 1)
	end
	local scratch = vim.api.nvim_create_buf(false, true)
	vim.bo[scratch].modifiable = false -- Exclude staging from the existing BufLeave autosave.
	-- The native engine passes replacements as gsub strings. Escape literal %
	-- from filenames or custom expressions only while this render is running.
	local original_replacements = renderer.expression_replacer_map
	local replacements = {}
	for expression, replace in pairs(original_replacements) do
		replacements[expression] = function(...)
			local value = replace(...)
			return type(value) == "string" and value:gsub("%%", "%%%%") or value
		end
	end
	renderer.expression_replacer_map = replacements
	local ok, result = pcall(function()
		vim.api.nvim_buf_set_name(scratch, context.target)
		vim.b[scratch].template_variables = context.variables
		return vim.api.nvim_buf_call(scratch, function()
			local lines, cursor = {}, nil
			for _, line in ipairs(source) do
				line = line:gsub(vim.pesc(cursor_marker), function()
					return cursor_token
				end)
				local expanded = renderer.render_line(line)
				local position = expanded:find(cursor_token, 1, true)
				if position then
					if cursor or expanded:find(cursor_token, position + #cursor_token, true) then
						error("O template deve conter apenas um marcador de cursor.")
					end
					cursor = { #lines + 1, position - 1 }
					expanded = expanded:gsub(cursor_token, "")
				end
				lines[#lines + 1] = expanded
			end
			return { lines = lines, cursor = cursor or { 1, 0 } }
		end)
	end)
	renderer.expression_replacer_map = original_replacements
	vim.api.nvim_buf_delete(scratch, { force = true })
	if not ok then
		error(result)
	end
	return result
end

function M.setup()
	require("template").register("{{_namespace_}}", function()
		return (vim.b.template_variables or {}).namespace or ""
	end)
end

return M
