-- Completion: blink.cmp, LuaSnip, and Copilot through the Blink menu.

-- Build hooks must be registered before vim.pack.add() is called.
vim.api.nvim_create_autocmd("PackChanged", {
	callback = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		if name == "LuaSnip" and (kind == "install" or kind == "update") then
			if vim.fn.has("win32") == 0 and vim.fn.executable("make") == 1 then
				vim.system({ "make", "install_jsregexp" }, { cwd = ev.data.path })
			end
		end
	end,
})

vim.pack.add({
	-- Completion engine
	{ src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1.x") },
	"https://github.com/giuxtaposition/blink-cmp-copilot",
	-- Snippets
	{ src = "https://github.com/L3MON4D3/LuaSnip", version = vim.version.range("2.x") },
	-- Neovim Lua API completions
	"https://github.com/folke/lazydev.nvim",
	-- GitHub Copilot (provided through blink.cmp)
	"https://github.com/zbirenbaum/copilot.lua",
})

-- lazydev: Neovim Lua API types & completions for Lua config files
require("lazydev").setup({
	library = {
		{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
		{ path = "snacks.nvim", words = { "Snacks" } },
	},
})

-- LuaSnip
require("luasnip").setup({})
require("snippets.typescript")
require("snippets.react")

-- blink.cmp
--- @module 'blink.cmp'
--- @type blink.cmp.Config
local copilot_completion = require("config.copilot_completion")

require("blink.cmp").setup({
	keymap = {
		preset = "default",
		["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
		["<A-j>"] = { "select_next", "fallback" },
		["<A-k>"] = { "select_prev", "fallback" },
		["<Esc>"] = { "hide", "fallback" },
	},
	appearance = { nerd_font_variant = "mono" },
	completion = {
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 150,
			window = { max_width = 72, max_height = 16, desired_min_width = 50, desired_min_height = 8 },
		},
	},
	sources = {
		default = { "lsp", "path", "snippets", "lazydev", "copilot" },
		providers = {
			copilot = {
				name = "copilot",
				module = "blink-cmp-copilot",
				score_offset = 100,
				async = true,
				transform_items = copilot_completion.format_items,
				enabled = function()
					return vim.g.copilot_completion_enabled
				end,
			},
			lazydev = { module = "lazydev.integrations.blink", score_offset = 100 },
		},
	},
	snippets = { preset = "luasnip" },
	fuzzy = { implementation = "prefer_rust_with_warning" },
	signature = { enabled = true },
})

vim.g.copilot_completion_enabled = vim.g.copilot_completion_enabled ~= false

-- Let Blink own all completion text edits. Inline Copilot suggestions and its
-- keymaps are disabled because they can race Blink while text is being typed.
require("copilot").setup({
	suggestion = { enabled = false },
	panel = { enabled = false },
	filetypes = {
		markdown = true,
		yaml = true,
		help = false,
		gitcommit = false,
		gitrebase = false,
		hgcommit = false,
		svn = false,
		cvs = false,
		["."] = false,
	},
})

vim.api.nvim_create_user_command("CopilotToggle", function()
	vim.g.copilot_completion_enabled = not vim.g.copilot_completion_enabled
	require("blink.cmp").hide()
	vim.notify(("Sugestões do Copilot %s."):format(vim.g.copilot_completion_enabled and "habilitadas" or "desabilitadas"))
end, { desc = "Enable or disable Copilot completion suggestions" })

vim.keymap.set("n", "<leader>ca", "<cmd>Copilot auth<CR>", { desc = "[C]opilot [A]uthenticate" })
vim.keymap.set("n", "<leader>ct", "<cmd>CopilotToggle<CR>", { desc = "[C]opilot [T]oggle suggestions" })
