local M = {}

local function jump(direction)
	local tabout = package.loaded["tabout"]
	if not tabout or not tabout.is_enabled() or vim.bo.buftype ~= "" then
		return false
	end
	local mode = vim.api.nvim_get_mode().mode
	if mode:sub(1, 1) ~= "i" then
		return false
	end
	local before = vim.api.nvim_win_get_cursor(0)
	if direction == "backward" and before[2] == 0 then
		return false
	end
	-- Unknown filetypes and parser-less buffers retain their existing fallback.
	local parsed, parser = pcall(vim.treesitter.get_parser, 0)
	if not parsed or not parser then
		return false
	end
	if vim.tbl_contains(require("tabout.config").options.exclude, vim.bo.filetype) then
		return false
	end
	local nodes = require("tabout.node")
	local ok, row, col = pcall(function()
		local node = nodes.get_node_at_cursor(direction)
		if node and node:parent() then
			return nodes.get_tabout_position(node, direction, false)
		end
	end)
	if not ok or not row or vim.deep_equal(before, { row + 1, col }) then
		return false
	end
	-- Expression mappings restore the cursor; run the plugin after evaluation.
	local buffer, window = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
	vim.schedule(function()
		if
			vim.api.nvim_get_current_buf() ~= buffer
			or vim.api.nvim_get_current_win() ~= window
			or not vim.deep_equal(before, vim.api.nvim_win_get_cursor(0))
		then
			return
		end
		local action = direction == "forward" and tabout.tabout or tabout.taboutBack
		action()
	end)
	return true
end

function M.forward()
	return jump("forward")
end

function M.backward()
	return jump("backward")
end

return M
