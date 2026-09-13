-- Editor utilities: autopairs, indent guides, linting, highlighting, auto-save,
-- guess-indent, todo-comments, img-clip, undotree, wakatime, suda, visual-multi,
-- grammarly LSP.

vim.pack.add({
	-- Autopairs
	"https://github.com/windwp/nvim-autopairs",
	-- Indent guides
	"https://github.com/lukas-reineke/indent-blankline.nvim",
	-- Linting
	"https://github.com/mfussenegger/nvim-lint",
	-- Color highlighting
	"https://github.com/brenoprata10/nvim-highlight-colors",
	-- Auto-save
	"https://github.com/Pocco81/auto-save.nvim",
	-- Auto-detect tab/space indentation
	"https://github.com/NMAC427/guess-indent.nvim",
	-- Todo comment highlights
	"https://github.com/folke/todo-comments.nvim",
	-- Paste images from clipboard into Markdown
	"https://github.com/HakonHarnes/img-clip.nvim",
	-- Persistent undo history tree (mapped to <F5>)
	"https://github.com/mbbill/undotree",
	-- Edit files as sudo (:SudaWrite)
	"https://github.com/lambdalisue/suda.vim",
	-- Multi-cursor (Ctrl+N)
	{ src = "https://github.com/mg979/vim-visual-multi", version = "master" },
	-- Grammarly LSP for prose
	"https://github.com/emacs-grammarly/lsp-grammarly",
	-- F# language support
	"https://github.com/ionide/Ionide-vim",
	-- Smart comment toggling
	"https://github.com/numToStr/Comment.nvim",
	-- Flash
	"https://github.com/folke/flash.nvim",
})

-- autopairs
require("nvim-autopairs").setup({})

-- indent-blankline
require("ibl").setup({})

-- nvim-lint
local lint = require("lint")
lint.linters_by_ft = {
	markdown = { "markdownlint-cli2" },
	javascript = { "eslint_d" },
	javascriptreact = { "eslint_d" },
	typescript = { "eslint_d" },
	typescriptreact = { "eslint_d" },
}
local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
	group = lint_augroup,
	callback = function()
		if vim.bo.modifiable then
			lint.try_lint()
		end
	end,
})

-- nvim-highlight-colors
require("nvim-highlight-colors").setup({ render = "background" })

-- auto-save
require("auto-save").setup({
	trigger_events = { "BufLeave" },
	condition = function(buf)
		return vim.fn.getbufvar(buf, "&modifiable") == 1
			and #vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR }) == 0
	end,
})

-- guess-indent
require("guess-indent").setup({})

-- todo-comments
require("todo-comments").setup({ signs = false })

-- Comment.nvim
require("Comment").setup({
	mappings = false,
	pre_hook = function(ctx)
		local ft = require("Comment.ft")
		local ok, parser = pcall(vim.treesitter.get_parser, 0)
		-- Neovim can return nil without throwing when no parser is available.
		local commentstring = ok and parser and ft.calculate(ctx)
			or ft.get(vim.bo.filetype, ctx.ctype)
			or vim.bo.commentstring
		if type(commentstring) == "string" and commentstring:find("%s", 1, true) then
			return commentstring
		end
		return "# %s"
	end,
})

local comment = require("Comment.api")
for _, mapping in ipairs({ { "n", "gc" }, { "n", "gcc" }, { "x", "gc" } }) do
	pcall(vim.keymap.del, unpack(mapping))
end

local comment_key = "<M-;>"
vim.keymap.set("n", comment_key, comment.toggle.linewise.current, {
	desc = "Toggle comment on current line",
})
vim.keymap.set(
	"x",
	comment_key,
	'<ESC><CMD>lua require("Comment.api").locked("toggle.linewise")(vim.fn.visualmode())<CR>',
	{
		desc = "Toggle comment on selected lines",
	}
)

-- img-clip
local year = os.date("%Y")
require("img-clip").setup({
	default = {
		dir_path = "/home/titus/github/website/static/images/" .. year .. "/",
		extension = "webp",
		process_cmd = "/usr/bin/cwebp -quiet -q 80 -o - -- - 2>/dev/null",
		template = "![$FILE_NAME_NO_EXT](/images/" .. year .. "/$FILE_NAME)",
		relative_template_path = false,
	},
	filetypes = {
		markdown = { template = "![$FILE_NAME_NO_EXT](/images/" .. year .. "/$FILE_NAME)" },
	},
})

-- Flash
local keymap = vim.keymap.set
keymap({ "n", "v" }, "<leader>fk", function()
	require("flash").jump({
		search = { forward = true, wrap = false, multi_window = false },
	})
end, { noremap = true, silent = true, desc = "flash Forward" })
keymap({ "n", "v" }, "<leader>fK", function()
	require("flash").jump({
		search = { forward = false, wrap = false, multi_window = false },
	})
end, { noremap = true, silent = True, desc = "flash Backward" })
