-- Treesitter context UI on top of Neovim 0.12 built-in treesitter.

vim.pack.add({
	"https://github.com/nvim-treesitter/nvim-treesitter",
	"https://github.com/nvim-treesitter/nvim-treesitter-context",
	"https://github.com/windwp/nvim-ts-autotag",
	"https://github.com/prisma/vim-prisma",
})

local treesitter_parsers = { "c_sharp", "html", "java", "javascript", "typescript", "tsx", "yaml" }
local missing_parsers = vim.tbl_filter(function(parser)
	return #vim.api.nvim_get_runtime_file(("parser/%s.*"):format(parser), true) == 0
end, treesitter_parsers)

if #missing_parsers > 0 then
	require("nvim-treesitter").install(missing_parsers)
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "cs", "java" },
	group = vim.api.nvim_create_augroup("language-treesitter-highlight", { clear = true }),
	callback = function(event)
		vim.treesitter.start(event.buf)
	end,
})

vim.filetype.add({
	extension = {
		prisma = "prisma",
	},
})

require("treesitter-context").setup({ max_lines = 3 })

require("nvim-ts-autotag").setup({
	opts = {
		enable_close = true,
		enable_rename = true,
		enable_close_on_slash = false,
	},
})

local html_void_tags = {
	"area",
	"base",
	"br",
	"col",
	"command",
	"embed",
	"hr",
	"img",
	"slot",
	"input",
	"keygen",
	"link",
	"meta",
	"param",
	"source",
	"track",
	"wbr",
	"menuitem",
}

local function add_missing_values(values, add)
	local out = vim.deepcopy(values or {})
	for _, value in ipairs(add) do
		if not vim.tbl_contains(out, value) then
			table.insert(out, value)
		end
	end
	return out
end

local autotag_configs = require("nvim-ts-autotag.config.init")
for _, filetype in ipairs(autotag_configs:get_supported_filetypes()) do
	local cfg = autotag_configs:get(filetype)
	if cfg and cfg.patterns and cfg.patterns.skip_tag_pattern then
		cfg.patterns.skip_tag_pattern = add_missing_values(cfg.patterns.skip_tag_pattern, html_void_tags)
		autotag_configs:add(cfg)
	end
end

local function get_void_tag_before_cursor()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local before_cursor = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]:sub(1, col)
	local tag = before_cursor:match("<%s*([%w:-]+)[^<>]*$")

	if tag and vim.tbl_contains(html_void_tags, tag:lower()) and not before_cursor:match("/%s*$") then
		return before_cursor:match("%s$") and "/>" or " />"
	end
end

local function setup_autotag_keymaps(bufnr)
	if not autotag_configs:get(vim.bo[bufnr].filetype) then
		return
	end

	vim.keymap.set("i", ">", function()
		local row, col = unpack(vim.api.nvim_win_get_cursor(0))
		local close = get_void_tag_before_cursor()

		if close then
			vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, { close })
			vim.api.nvim_win_set_cursor(0, { row, col + #close })
			return
		end

		vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, { ">" })
		require("nvim-ts-autotag.internal").close_tag()
		vim.api.nvim_win_set_cursor(0, { row, col + 1 })
	end, { buffer = bufnr, noremap = true, silent = true })
end

vim.api.nvim_create_autocmd("InsertEnter", {
	group = vim.api.nvim_create_augroup("custom-autotag-void-close", { clear = true }),
	callback = function(event)
		vim.schedule(function()
			if vim.api.nvim_buf_is_valid(event.buf) then
				setup_autotag_keymaps(event.buf)
			end
		end)
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("custom-autotag-live-rename", { clear = true }),
	callback = function(event)
		if not autotag_configs:get(vim.bo[event.buf].filetype) then
			return
		end
		setup_autotag_keymaps(event.buf)
		vim.api.nvim_create_autocmd("TextChangedI", {
			buffer = event.buf,
			callback = function()
				require("nvim-ts-autotag.internal").rename_tag()
			end,
		})
	end,
})

setup_autotag_keymaps(vim.api.nvim_get_current_buf())
