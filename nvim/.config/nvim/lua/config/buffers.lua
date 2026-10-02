local M = {}

function M.close(bufnr, force)
	local current = bufnr and bufnr ~= 0 and bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(current) then
		return
	end
	local remaining = vim.tbl_filter(function(buffer)
		return buffer.bufnr ~= current and vim.bo[buffer.bufnr].buftype == ""
	end, vim.fn.getbufinfo({ buflisted = 1 }))

	-- Quit the session, including explorer windows, when the last editing buffer closes.
	if #remaining == 0 then
		vim.cmd(force and "qall!" or "qall")
		return
	end

	-- Preserve :bdelete's refusal to discard changes; Snacks otherwise prompts to save.
	if vim.bo[current].modified and not force then
		vim.notify("Buffer possui alterações não salvas. Use <leader>w para salvar ou <leader>kf para descartar.", vim.log.levels.ERROR)
		return
	end

	require("snacks").bufdelete({ buf = current, force = force })
end

return M
