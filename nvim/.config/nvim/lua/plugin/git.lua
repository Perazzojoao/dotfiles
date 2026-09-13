-- Git: gitsigns for hunk navigation, staging, blame, and diff.

vim.pack.add({
	"https://github.com/lewis6991/gitsigns.nvim",
	"https://github.com/kdheepak/lazygit.nvim",
})

require("gitsigns").setup()

local gs = require("gitsigns")
local map = vim.keymap.set

map("n", "<leader>gg", "<cmd>LazyGit<CR>", { desc = "Open LazyGit" })
map("n", "<leader>gh", function()
	Snacks.terminal("hunk diff --watch")
end, { desc = "Run hunk diff watch" })
map("n", "<leader>gs", gs.stage_hunk, { desc = "Stage hunk" })
map("n", "<leader>gr", gs.reset_hunk, { desc = "Reset hunk" })
map("n", "<leader>gS", gs.stage_buffer, { desc = "Stage buffer" })
map("n", "<leader>gR", gs.reset_buffer, { desc = "Reset buffer" })
map("n", "<leader>gp", gs.preview_hunk, { desc = "Preview hunk" })
map("n", "<leader>gl", function()
	gs.blame_line({ full = true })
end, { desc = "Blame line" })
map("n", "<leader>gd", gs.diffthis, { desc = "Diff this" })
map("n", "<leader>gb", gs.toggle_current_line_blame, { desc = "Toggle git blame" })
map("n", "<leader>gw", gs.toggle_word_diff, { desc = "Toggle word diff" })
