-- Blink handles menu completion and snippets; Copilot shows inline suggestions.

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
	-- Snippets
	{ src = "https://github.com/L3MON4D3/LuaSnip", version = vim.version.range("2.x") },
	-- Neovim Lua API completions
	"https://github.com/folke/lazydev.nvim",
	-- GitHub Copilot inline suggestions
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
require("snippets.csharp")

vim.g.copilot_inline_enabled = vim.g.copilot_inline_enabled ~= false

local function handle_completion_tab(cmp)
	-- LuaSnip's global jumpable state can outlive the snippet under the cursor.
	if require("luasnip").locally_jumpable(1) then
		cmp.hide()
		local suggestion = require("copilot.suggestion")
		if suggestion.is_visible() then
			suggestion.dismiss()
		end
		return cmp.snippet_forward()
	end
	if cmp.is_menu_visible() then
		return cmp.select_and_accept()
	end
	if cmp.snippet_active({ direction = 1 }) then
		return cmp.snippet_forward()
	end
	local suggestion = require("copilot.suggestion")
	if suggestion.is_visible() then
		suggestion.accept()
		return true
	end
end

-- blink.cmp
--- @module 'blink.cmp'
--- @type blink.cmp.Config
require("blink.cmp").setup({
	keymap = {
		preset = "default",
		["<C-k>"] = false, -- Signature help is handled by the native LSP popup.
		["<Tab>"] = {
			handle_completion_tab,
			"select_and_accept",
			require("config.tabout").forward,
			"fallback",
		},
		["<S-Tab>"] = { "snippet_backward", require("config.tabout").backward, "fallback" },
		["<A-j>"] = { "select_next", "fallback" },
		["<A-k>"] = { "select_prev", "fallback" },
		["<Esc>"] = { "hide", "fallback" },
	},
	appearance = { nerd_font_variant = "mono" },
	completion = {
		trigger = { show_in_snippet = false },
		list = { selection = { auto_insert = false } },
		menu = { border = "rounded", auto_show = true },
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 150,
			window = {
				border = "rounded",
				max_width = 72,
				max_height = 16,
				desired_min_width = 50,
				desired_min_height = 8,
			},
		},
	},
	sources = {
		default = { "lsp", "path", "snippets", "lazydev" },
		providers = {
			lazydev = { module = "lazydev.integrations.blink", score_offset = 100 },
		},
	},
	snippets = { preset = "luasnip" },
	fuzzy = { implementation = "prefer_rust_with_warning", sorts = require("config.completion_ranking").sorts },
	signature = { enabled = false },
})

require("copilot").setup({
	suggestion = {
		enabled = true,
		auto_trigger = true,
		trigger_on_accept = false,
		keymap = { accept = false, accept_word = "<C-Right>" },
	},
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

-- Blink installs its buffer-local Tab mapping after the fuzzy matcher initializes.
-- Keep Copilot acceptance available while that asynchronous setup is pending.
vim.keymap.set("i", "<Tab>", function()
	if handle_completion_tab(require("blink.cmp")) then
		return ""
	end
	if vim.snippet.active({ direction = 1 }) then
		vim.snippet.jump(1)
		return ""
	end
	if require("config.tabout").forward() then
		return ""
	end
	return vim.api.nvim_replace_termcodes("<Tab>", true, true, true)
end, { expr = true, replace_keycodes = false, desc = "Completion Tab fallback while Blink loads" })

vim.api.nvim_create_autocmd("User", {
	pattern = { "BlinkCmpMenuOpen", "BlinkCmpMenuClose" },
	group = vim.api.nvim_create_augroup("copilot-blink-menu", { clear = true }),
	callback = function(event)
		vim.b[event.buf].copilot_suggestion_hidden = event.match == "BlinkCmpMenuOpen"
	end,
})

if not vim.g.copilot_inline_enabled then
	require("copilot.command").disable()
end

vim.api.nvim_create_user_command("CopilotToggle", function()
	vim.g.copilot_inline_enabled = not vim.g.copilot_inline_enabled
	local command = require("copilot.command")
	if vim.g.copilot_inline_enabled then
		command.enable()
	else
		local suggestion = require("copilot.suggestion")
		if suggestion.is_visible() then
			suggestion.dismiss()
		end
		command.disable()
	end
	vim.notify(("Sugestões do Copilot %s."):format(vim.g.copilot_inline_enabled and "habilitadas" or "desabilitadas"))
end, { desc = "Enable or disable Copilot inline suggestions" })

vim.keymap.set("n", "<leader>ca", "<cmd>Copilot auth<CR>", { desc = "[C]opilot [A]uthenticate" })
vim.keymap.set("n", "<leader>ct", "<cmd>CopilotToggle<CR>", { desc = "[C]opilot [T]oggle suggestions" })
