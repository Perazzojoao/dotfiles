local M = {}

local function text_before_cursor(context, range)
	local cursor_row, cursor_col = unpack(context.cursor)
	local start_row = range and range.start and range.start.line or cursor_row - 1
	local preceding_lines = vim.api.nvim_buf_get_lines(context.bufnr, start_row, cursor_row - 1, false)
	local current_line = context.line or vim.api.nvim_buf_get_lines(context.bufnr, cursor_row - 1, cursor_row, false)[1] or ""
	local start_col = start_row == cursor_row - 1 and range and range.start and range.start.character or 0

	table.insert(preceding_lines, current_line:sub(start_col + 1, cursor_col))
	return table.concat(preceding_lines, "\n")
end

--- Returns only the part of a Copilot completion that is not already before the cursor.
--- The full text edit remains untouched so accepting the item keeps Copilot's range.
---@param context blink.cmp.Context
---@param suggestion string
---@param range? lsp.Range
---@return string
function M.only_new_text(context, suggestion, range)
	local existing_text = text_before_cursor(context, range)
	local maximum_overlap = math.min(#existing_text, #suggestion)

	for overlap = maximum_overlap, 1, -1 do
		if existing_text:sub(-overlap) == suggestion:sub(1, overlap) then
			return suggestion:sub(overlap + 1)
		end
	end

	return suggestion
end

--- Keeps Blink's matching and acceptance data while making Copilot menu labels concise.
---@param context blink.cmp.Context
---@param items blink.cmp.CompletionItem[]
---@return blink.cmp.CompletionItem[]
function M.format_items(context, items)
	local formatted_items = {}

	for _, item in ipairs(items) do
		local completion_text = item.textEdit and item.textEdit.newText or item.insertText or item.label
		local new_text = M.only_new_text(context, completion_text or "", item.textEdit and item.textEdit.range)

		if new_text:find("%S") then
			item.filterText = item.filterText or item.label
			item.label = new_text
			item.documentation = {
				kind = "markdown",
				value = new_text,
			}
			table.insert(formatted_items, item)
		end
	end

	return formatted_items
end

return M
