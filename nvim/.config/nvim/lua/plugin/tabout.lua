vim.pack.add({ "https://github.com/abecodes/tabout.nvim" })

-- Blink owns Tab/Shift-Tab; tabout only handles the final navigation fallback.
require("tabout").setup({
	tabkey = "",
	backwards_tabkey = "",
	act_as_tab = false,
	act_as_shift_tab = false,
	completion = false,
})
