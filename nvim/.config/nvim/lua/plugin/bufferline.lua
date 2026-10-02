-- Shared closing logic preserves explorer windows and handles the clicked buffer ID.
local function close_buffer(bufnr)
	require("config.buffers").close(bufnr, false)
end

require("bufferline").setup({
	options = {
		mode = "buffers",
		close_command = close_buffer,
		right_mouse_command = close_buffer,
		diagnostics = "nvim_lsp",
		offsets = { { filetype = "snacks_layout_box", text = "Explorer" } },
		separator_style = "slant",
		always_show_bufferline = true,
		enforce_regular_tabs = true,
	},
	highlights = {
		buffer_selected = { bold = true, italic = false },
		indicator_selected = { bold = true },
	},
})
