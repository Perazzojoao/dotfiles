-- Markdown rendering with a buffer-local toggle for Markdown documents.
vim.pack.add({
	"https://github.com/MeanderingProgrammer/render-markdown.nvim",
})

require("render-markdown").setup({
	file_types = { "markdown" },
})

local function toggle_markdown_globally()
	local markdown = require("render-markdown")
	local manager = require("render-markdown.core.manager")
	local state = require("render-markdown.state")

	-- Buffers opened before the plugin's FileType handler are not tracked by
	-- render-markdown, so attach them before changing the global state.
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.tbl_contains(state.file_types, vim.bo[bufnr].filetype) then
			manager.attach(bufnr)
		end
	end

	markdown.toggle()
end

vim.keymap.set("n", "<leader>mm", function()
	toggle_markdown_globally()
end, { desc = "Toggle [M]arkdown rendering globally" })

vim.keymap.set("n", "<leader>mb", function()
	require("render-markdown").buf_toggle()
end, { desc = "Toggle [M]arkdown rendering for current [B]uffer" })
