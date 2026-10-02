-- LSP: server configuration, Mason installer, formatter (conform), linting.

vim.pack.add({
	"https://github.com/neovim/nvim-lspconfig",
	{ src = "https://github.com/mason-org/mason.nvim", version = "main" },
	"https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim",
	{ src = "https://github.com/j-hui/fidget.nvim", version = "main" },
	-- Autoformat on save
	"https://github.com/stevearc/conform.nvim",
})

-- Mason
require("mason").setup({})

-- Fidget: LSP progress notifications
require("fidget").setup({})

-- Conform: autoformat
require("conform").setup({
	notify_on_error = false,
	format_on_save = function(bufnr)
		local disable_filetypes = { c = true, cpp = true }
		if disable_filetypes[vim.bo[bufnr].filetype] then
			return nil
		end
		return { timeout_ms = vim.bo[bufnr].filetype == "cs" and 5000 or 500, lsp_format = "fallback" }
	end,
	formatters_by_ft = {
		-- Roslyn honors .editorconfig, including the C# brace style.
		java = { "google-java-format" },
		lua = { "stylua" },
		javascript = { "prettierd", "prettier", stop_after_first = true },
		javascriptreact = { "prettierd", "prettier", stop_after_first = true },
		typescript = { "prettierd", "prettier", stop_after_first = true },
		typescriptreact = { "prettierd", "prettier", stop_after_first = true },
		-- python     = { 'isort', 'black' },
	},
})
vim.keymap.set("", "<leader>=", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "[F]ormat buffer" })

vim.cmd([[nnoremenu PopUp.Code\ Actions <Cmd>lua vim.lsp.buf.code_action()<CR>]])
vim.cmd([[vnoremenu PopUp.Code\ Actions <Cmd>lua vim.lsp.buf.code_action()<CR>]])

local kubernetes_manifest_patterns = {
	"**/k8s/**/*.yaml",
	"**/k8s/**/*.yml",
	"**/kubernetes/**/*.yaml",
	"**/kubernetes/**/*.yml",
	"manifests/**/*.yaml",
	"manifests/**/*.yml",
	"**/manifests/**/*.yaml",
	"**/manifests/**/*.yml",
	"**/*.k8s.yaml",
	"**/*.k8s.yml",
}

local roslyn_diagnostics_group = vim.api.nvim_create_augroup("roslyn-lsp-diagnostics", { clear = true })
local function refresh_roslyn_diagnostics(client)
	for bufnr in pairs(client.attached_buffers) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			-- Native refresh preserves provider identifiers and result IDs. Unnamed
			-- pulls create a separate namespace and duplicate the named providers.
			vim.lsp.diagnostic._refresh(bufnr, client.id)
		end
	end
end

-- LSP servers to configure
local servers = {
	-- clangd = {}, rust_analyzer = {}
	gopls = {},
	roslyn_ls = {
		handlers = {
			["workspace/projectInitializationComplete"] = function(_, _, ctx)
				vim.notify("Roslyn project initialization complete", vim.log.levels.INFO, { title = "roslyn_ls" })
				local client = vim.lsp.get_client_by_id(ctx.client_id)
				if client then
					refresh_roslyn_diagnostics(client)
				end
				return vim.NIL
			end,
		},
		on_attach = function(client, bufnr)
			vim.api.nvim_clear_autocmds({ group = roslyn_diagnostics_group, buffer = bufnr })
			vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
				group = roslyn_diagnostics_group,
				buffer = bufnr,
				callback = function()
					refresh_roslyn_diagnostics(client)
				end,
				desc = "roslyn_ls: refresh provider diagnostics",
			})
		end,
	},
	jdtls = {
		before_init = function(_, config)
			local root = config.root_dir
			if root and vim.fn.isdirectory(vim.fs.joinpath(root, "src")) == 1 then
				-- JDTLS otherwise treats files under src/<package> as default-package files
				-- in Java projects without Maven, Gradle, or Eclipse project metadata.
				config.settings.java.project = { sourcePaths = { "src" } }
			end
		end,
		settings = {
			java = {
				completion = {
					favoriteStaticMembers = {
						"java.util.Objects.requireNonNull",
						"java.util.Objects.requireNonNullElse",
						"org.junit.jupiter.api.Assertions.*",
						"org.mockito.Mockito.*",
					},
				},
				configuration = { updateBuildConfiguration = "interactive" },
				implementationsCodeLens = { enabled = true },
				referencesCodeLens = { enabled = true },
			},
		},
	},
	prismals = {},
	pyright = {},
	tailwindcss = {},
	ts_ls = {},
	yamlls = {
		settings = {
			yaml = {
				-- Keep generic YAML schemas intact; Kubernetes completion applies to
				-- conventional manifest directories and filenames.
				schemas = {
					kubernetes = kubernetes_manifest_patterns,
				},
				-- SchemaStore identifies **/policies/**/*.yaml as an Aerleon
				-- policy. Disable only its automatic matches for Kubernetes paths;
				-- the explicit kubernetes schema above remains in effect.
				disableSchemaDetection = kubernetes_manifest_patterns,
			},
		},
	},
	lua_ls = {
		settings = { Lua = { completion = { callSnippet = "Replace" } } },
	},
}

-- Map LSP server names to Mason package names where they differ
local lsp_to_mason = {
	lua_ls = "lua-language-server",
	prismals = "prisma-language-server",
	roslyn_ls = "roslyn-language-server",
	tailwindcss = "tailwindcss-language-server",
	ts_ls = "typescript-language-server",
	yamlls = "yaml-language-server",
}
local ensure_installed = vim.tbl_keys(servers)
for i, name in ipairs(ensure_installed) do
	if lsp_to_mason[name] then
		ensure_installed[i] = lsp_to_mason[name]
	end
end
vim.list_extend(ensure_installed, { "stylua", "prettierd", "prettier", "eslint_d", "google-java-format" })
require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

-- Apply server configs and enable them
local capabilities = require("blink.cmp").get_lsp_capabilities()
for name, cfg in pairs(servers) do
	local server = vim.tbl_deep_extend("force", {}, cfg)
	server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
	vim.lsp.config[name] = server
	vim.lsp.enable(name)
end

-- LspAttach: keymaps and highlight on cursor
local lsp_popup_border = "rounded"
local function show_lsp_hover()
	vim.lsp.buf.hover({ border = lsp_popup_border })
end
local function show_lsp_signature(opts)
	vim.lsp.buf.signature_help(vim.tbl_extend("force", { border = lsp_popup_border }, opts or {}))
end

local insert_signature_opts = { focusable = false, close_events = { "InsertLeave" } }
local signature_help_group = vim.api.nvim_create_augroup("native-lsp-signature-help", { clear = true })
local signature_menu_group = vim.api.nvim_create_augroup("native-lsp-signature-menu", { clear = true })
local signature_hidden_by_user = {}
local signature_on_top = {}

local function insert_signature_win(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	local win = vim.b[bufnr].lsp_floating_preview
	if win and vim.api.nvim_win_is_valid(win) and vim.w[win]["textDocument/signatureHelp"] == bufnr then
		return win
	end
end

local function close_insert_signature(bufnr)
	local win = insert_signature_win(bufnr)
	if win then
		vim.api.nvim_win_close(win, true)
	end
end

local function signature_zindex(bufnr)
	if not signature_on_top[bufnr] then
		return 50
	end
	local top = 50
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].filetype:match("^blink%-cmp") then
			top = math.max(top, vim.api.nvim_win_get_config(win).zindex or 50)
		end
	end
	-- Blink's scrollbar thumb is two layers above its menu/documentation.
	return top + 3
end

local function apply_signature_layer(bufnr)
	local win = insert_signature_win(bufnr)
	if win then
		vim.api.nvim_win_set_config(win, { zindex = signature_zindex(bufnr) })
	end
end

local function show_insert_signature(bufnr, silent)
	vim.schedule(function()
		if
			vim.api.nvim_get_current_buf() ~= bufnr
			or not vim.api.nvim_get_mode().mode:match("^[is]")
			or signature_hidden_by_user[bufnr]
			or #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/signatureHelp" }) == 0
		then
			return
		end
		show_lsp_signature(vim.tbl_extend(
			"force",
			{ silent = silent, zindex = signature_zindex(bufnr) },
			insert_signature_opts
		))
	end)
end

local function toggle_insert_signature(bufnr)
	local blink_visible = require("blink.cmp").is_menu_visible()
	local win = insert_signature_win(bufnr)
	if blink_visible and win then
		signature_on_top[bufnr] = not signature_on_top[bufnr]
		apply_signature_layer(bufnr)
	elseif blink_visible then
		signature_hidden_by_user[bufnr] = nil
		signature_on_top[bufnr] = true
		show_insert_signature(bufnr, false)
	elseif win then
		signature_hidden_by_user[bufnr] = true
		signature_on_top[bufnr] = nil
		close_insert_signature(bufnr)
	else
		signature_hidden_by_user[bufnr] = nil
		signature_on_top[bufnr] = nil
		show_insert_signature(bufnr, false)
	end
end

vim.api.nvim_create_autocmd("User", {
	group = signature_menu_group,
	pattern = { "BlinkCmpMenuOpen", "BlinkCmpMenuClose" },
	callback = function(event)
		apply_signature_layer(event.buf)
		show_insert_signature(event.buf, true)
	end,
})

-- Apply the current layer choice to floats created by asynchronous LSP responses.
vim.api.nvim_create_autocmd("WinNew", {
	group = signature_menu_group,
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()
		vim.schedule(function()
			if signature_hidden_by_user[bufnr] then
				close_insert_signature(bufnr)
			else
				apply_signature_layer(bufnr)
			end
		end)
	end,
})

vim.api.nvim_create_autocmd("User", {
	group = signature_menu_group,
	pattern = "TaboutAfter",
	callback = function(event)
		close_insert_signature(event.buf)
		show_insert_signature(event.buf, true)
	end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
	group = signature_menu_group,
	callback = function(event)
		signature_hidden_by_user[event.buf] = nil
		signature_on_top[event.buf] = nil
	end,
})

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
	callback = function(event)
		local map = function(keys, func, desc, mode)
			mode = mode or "n"
			vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
		end

		map("grn", vim.lsp.buf.rename, "[R]e[n]ame")
		map("gra", vim.lsp.buf.code_action, "[G]oto Code [A]ction", { "n", "x" })
		map("H", show_lsp_hover, "Show hover information")
		map("gK", show_lsp_signature, "Show function signature")
		map("grr", function()
			require("snacks").picker.lsp_references()
		end, "[G]oto [R]eferences")
		map("gri", function()
			require("snacks").picker.lsp_implementations()
		end, "[G]oto [I]mplementation")
		map("grd", function()
			require("snacks").picker.lsp_definitions()
		end, "[G]oto [D]efinition")
		map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
		map("gO", function()
			require("snacks").picker.lsp_symbols()
		end, "Open Document Symbols")
		map("gW", function()
			require("snacks").picker.lsp_workspace_symbols()
		end, "Open Workspace Symbols")
		map("grt", function()
			require("snacks").picker.lsp_type_definitions()
		end, "[G]oto [T]ype Definition")

		---@param client vim.lsp.Client
		---@param method vim.lsp.protocol.Method
		---@param bufnr? integer
		---@return boolean
		local function client_supports_method(client, method, bufnr)
			return client:supports_method(method, bufnr)
		end

		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if
			client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_signatureHelp, event.buf)
		then
			map("<A-k>", function()
				toggle_insert_signature(event.buf)
			end, "Toggle completion/signature layer", "i")

			vim.api.nvim_clear_autocmds({ group = signature_help_group, buffer = event.buf })
			local trigger_characters = {}
			for _, attached in ipairs(vim.lsp.get_clients({ bufnr = event.buf, method = "textDocument/signatureHelp" })) do
				local provider = attached.server_capabilities.signatureHelpProvider
				if type(provider) == "table" then
					for _, character in ipairs(provider.triggerCharacters or {}) do
						trigger_characters[character] = true
					end
					for _, character in ipairs(provider.retriggerCharacters or {}) do
						trigger_characters[character] = true
					end
				end
			end

			local typed_trigger = nil
			vim.api.nvim_create_autocmd("InsertCharPre", {
				group = signature_help_group,
				buffer = event.buf,
				callback = function()
					typed_trigger = trigger_characters[vim.v.char] and vim.v.char or nil
				end,
			})
			vim.api.nvim_create_autocmd("TextChangedI", {
				group = signature_help_group,
				buffer = event.buf,
				callback = function()
					if typed_trigger then
						if typed_trigger == "(" then
							signature_hidden_by_user[event.buf] = nil
						end
						typed_trigger = false
						show_insert_signature(event.buf, true)
					end
				end,
			})
			vim.api.nvim_create_autocmd({ "InsertEnter", "CursorHoldI" }, {
				group = signature_help_group,
				buffer = event.buf,
				callback = function()
					show_insert_signature(event.buf, true)
				end,
			})
			vim.api.nvim_create_autocmd("InsertLeave", {
				group = signature_help_group,
				buffer = event.buf,
				callback = function()
					signature_hidden_by_user[event.buf] = nil
					signature_on_top[event.buf] = nil
				end,
			})
		end
		if
			client
			and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf)
		then
			local hl_group = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				buffer = event.buf,
				group = hl_group,
				callback = vim.lsp.buf.document_highlight,
			})
			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				buffer = event.buf,
				group = hl_group,
				callback = vim.lsp.buf.clear_references,
			})
			vim.api.nvim_create_autocmd("LspDetach", {
				group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
				callback = function(event2)
					vim.lsp.buf.clear_references()
					vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
				end,
			})
		end
	end,
})

vim.diagnostic.config({
	severity_sort = true,
	float = { border = lsp_popup_border, source = "if_many" },
	underline = { severity = vim.diagnostic.severity.ERROR },
	signs = vim.g.have_nerd_font and {
		text = {
			[vim.diagnostic.severity.ERROR] = "󰅚 ",
			[vim.diagnostic.severity.WARN] = "󰀪 ",
			[vim.diagnostic.severity.INFO] = "󰋽 ",
			[vim.diagnostic.severity.HINT] = "󰌶 ",
		},
	} or {},
	virtual_text = {
		source = "if_many",
		spacing = 2,
		format = function(d)
			return d.message
		end,
	},
})
