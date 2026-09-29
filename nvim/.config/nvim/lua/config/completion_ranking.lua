local M = {}

local kinds = vim.lsp.protocol.CompletionItemKind
local object_methods = {
	Equals = true,
	GetHashCode = true,
	GetType = true,
	ToString = true,
}
local default_sorts = { "score", "sort_text" }

local function is_csharp_member_access(ctx)
	return ctx
		and vim.api.nvim_buf_is_valid(ctx.bufnr)
		and vim.bo[ctx.bufnr].filetype == "cs"
		and ctx.line:sub(1, ctx.cursor[2]):match("%.[%w_]*$") ~= nil
end

local function group(item)
	if
		item.kind == kinds.Variable
		or item.kind == kinds.Field
		or item.kind == kinds.Property
		or item.kind == kinds.Constant
	then
		return 1
	end
	if item.kind == kinds.Method or item.kind == kinds.Function then
		-- The initial LSP completion does not identify the declaring type. Keep
		-- common System.Object names after other methods, with no kinds between.
		return item.source_id == "lsp" and object_methods[item.label] and 3 or 2
	end
	-- Keep each remaining completion kind together, in its numeric order.
	return 100 + (item.kind or 100)
end

function M.compare_groups(a, b)
	local first, second = group(a), group(b)
	if first ~= second then
		return first < second
	end
end

function M.sorts_for_context(ctx)
	if is_csharp_member_access(ctx) then
		return { M.compare_groups, "score", "sort_text" }
	end
	return default_sorts
end

function M.sorts()
	return M.sorts_for_context(require("blink.cmp").get_context())
end

return M
