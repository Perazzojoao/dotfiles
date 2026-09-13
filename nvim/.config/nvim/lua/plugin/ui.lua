vim.pack.add({
	-- Keybind hint popup
	"https://github.com/folke/which-key.nvim",
	-- mini.nvim editor utilities
	"https://github.com/echasnovski/mini.nvim",
	-- Statusline
	"https://github.com/nvim-lualine/lualine.nvim",
	"https://github.com/nvim-tree/nvim-web-devicons",
	-- Dashboard / start screen
	"https://github.com/goolord/alpha-nvim",
	-- Smooth animated scrolling
	"https://github.com/karb94/neoscroll.nvim",
	-- VSCode-style buffer tab bar
	{ src = "https://github.com/akinsho/bufferline.nvim", version = vim.version.range("*") },
	-- Problems panel (like VSCode Ctrl+Shift+M)
	"https://github.com/folke/trouble.nvim",
	-- Symbol outline sidebar
	"https://github.com/stevearc/aerial.nvim",
	-- File manager as a buffer (edit filesystem like text)
	"https://github.com/stevearc/oil.nvim",
	-- Search result positions for nvim-scrollbar
	"https://github.com/kevinhwang91/nvim-hlslens",
	-- Scroll bar
	{ src = "https://github.com/petertriho/nvim-scrollbar" },
})

-- which-key
require("which-key").setup({
	delay = 350,
	icons = {
		mappings = vim.g.have_nerd_font,
		keys = vim.g.have_nerd_font and {} or {
			Up = "<Up> ",
			Down = "<Down> ",
			Left = "<Left> ",
			Right = "<Right> ",
			C = "<C-…> ",
			M = "<M-…> ",
			D = "<D-…> ",
			S = "<S-…> ",
			CR = "<CR> ",
			Esc = "<Esc> ",
			ScrollWheelDown = "<ScrollWheelDown> ",
			ScrollWheelUp = "<ScrollWheelUp> ",
			NL = "<NL> ",
			BS = "<BS> ",
			Space = "<Space> ",
			Tab = "<Tab> ",
			F1 = "<F1>",
			F2 = "<F2>",
			F3 = "<F3>",
			F4 = "<F4>",
			F5 = "<F5>",
			F6 = "<F6>",
			F7 = "<F7>",
			F8 = "<F8>",
			F9 = "<F9>",
			F10 = "<F10>",
			F11 = "<F11>",
			F12 = "<F12>",
		},
	},
	spec = {
		{ "<leader>s", group = "[S]earch" },
		{ "<leader>g", group = "[G]it", mode = { "n", "v" } },
	},
})

-- mini.nvim (only icons + statusline)
require("mini.icons").setup()
require("mini.ai").setup({ n_lines = 500 })
require("mini.surround").setup()
require("mini.cmdline").setup({
	autocorrect = { enabled = false },
	autocomplete = {
		enabled = true,
		delay = 0,
	},
})
require("mini.diff").setup()
require("lualine").setup({
	options = {
		icons_enabled = vim.g.have_nerd_font,
		theme = "tokyonight",
		component_separators = { left = "", right = "" },
		section_separators = { left = "", right = "" },
		globalstatus = true,
	},
	sections = {
		lualine_a = { "mode" },
		lualine_b = { "branch" },
		lualine_c = { { "filename", path = 1 } },
		lualine_x = { "filetype" },
		lualine_y = { "searchcount" },
		lualine_z = { "location" },
	},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = { { "filename", path = 1 } },
		lualine_x = { "location" },
		lualine_y = {},
		lualine_z = {},
	},
})

-- neoscroll
local neoscroll = require("neoscroll")
neoscroll.setup({
	mappings = {},
	hide_cursor = true,
	stop_eof = true,
	easing = "sine",
	post_hook = function(info)
		if type(info) == "table" and info.center then
			vim.cmd("normal! zz")
		end
	end,
})
vim.keymap.set("n", "<C-u>", function()
	neoscroll.ctrl_u({ duration = 150, info = { center = true } })
end, { desc = "Smooth scroll up" })
vim.keymap.set("n", "<C-d>", function()
	neoscroll.ctrl_d({ duration = 150, info = { center = true } })
end, { desc = "Smooth scroll down" })

vim.keymap.set("n", "<leader>W", function()
	vim.wo.wrap = not vim.wo.wrap
end, { desc = "Toggle line [W]rap" })

-- alpha dashboard
local dashboard = require("alpha.themes.dashboard")
dashboard.config.layout = {
	{
		type = "group",
		val = {
			dashboard.section.header,
			{ type = "padding", val = 2 },
			dashboard.section.buttons,
			dashboard.section.footer,
		},
		opts = { position = "v_center" },
	},
}
require("alpha").setup(dashboard.config)

-- bufferline
require("bufferline").setup({
	options = {
		mode = "buffers",
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

-- trouble
require("trouble").setup({})
vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Diagnostics (Trouble)" })
vim.keymap.set("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", { desc = "Buffer Diagnostics" })
vim.keymap.set("n", "<leader>xs", "<cmd>Trouble symbols toggle<CR>", { desc = "Symbols (Trouble)" })

-- aerial
require("aerial").setup({})
vim.keymap.set("n", "<leader>v", "<cmd>AerialToggle!<CR>", { desc = "Toggle outline [V]iew" })

-- oil
local oil = require("oil")
oil.setup({
	columns = { "icon" },
	keymaps = {
		["<C-l>"] = false,
		["<C-j>"] = false,
		["<M-h>"] = "actions.select_split",
		["q"] = "actions.close",
		["<Esc>"] = "actions.close",
	},
	view_options = { show_hidden = true },
})
vim.keymap.set("n", "-", oil.open, { desc = "Open parent directory (oil)" })
vim.keymap.set("n", "<leader>o", oil.toggle_float, { desc = "Toggle oil float" })

-- Scroll bar
require("hlslens").setup()
local colors = require("tokyonight.colors").setup()
require("scrollbar").setup({
	handle = {
		color = colors.bg_highlight,
	},
	marks = {
		Cursor = { color = colors.fg },
		Search = { color = colors.orange },
		Error = { color = colors.error },
		Warn = { color = colors.warning },
		Info = { color = colors.info },
		Hint = { color = colors.hint },
		Misc = { color = colors.purple },
		GitAdd = { color = colors.git.add },
		GitChange = { color = colors.git.change },
		GitDelete = { color = colors.git.delete },
	},
	handlers = {
		cursor = true,
		diagnostic = true,
		gitsigns = true,
		handle = true,
		search = true,
		ale = false,
	},
})

local scrollbar_drag = { winid = nil, offset = 0, previous_mousemoveevent = nil }
local pending_scrollbar_view = nil
local scrollbar_view_scheduled = false

local function reset_scrollbar_drag()
	if scrollbar_drag.previous_mousemoveevent ~= nil then
		vim.o.mousemoveevent = scrollbar_drag.previous_mousemoveevent
	end

	scrollbar_drag.winid = nil
	scrollbar_drag.offset = 0
	scrollbar_drag.previous_mousemoveevent = nil
end

local function scrollbar_is_clickable(mouse)
	if mouse.winid == 0 or not vim.api.nvim_win_is_valid(mouse.winid) then
		return false
	end

	local config = require("scrollbar.config").get()
	local bufnr = vim.api.nvim_win_get_buf(mouse.winid)
	if
		not config.show
		or vim.tbl_contains(config.excluded_buftypes, vim.bo[bufnr].buftype)
		or vim.tbl_contains(config.excluded_filetypes, vim.bo[bufnr].filetype)
		or (config.max_lines and vim.api.nvim_buf_line_count(bufnr) > config.max_lines)
	then
		return false
	end

	return mouse.wincol == vim.api.nvim_win_get_width(mouse.winid)
		and vim.api.nvim_buf_line_count(bufnr) > vim.api.nvim_win_get_height(mouse.winid)
end

local function scrollbar_geometry(winid)
	local height = vim.api.nvim_win_get_height(winid)
	local bufnr = vim.api.nvim_win_get_buf(winid)
	local total_lines = vim.api.nvim_buf_line_count(bufnr)
	local max_topline = math.max(total_lines - height + 1, 1)
	local line_to_row_ratio = height / total_lines
	local handle_height = math.max(math.floor(height * line_to_row_ratio) + 1, 1)
	local current_topline = vim.api.nvim_win_call(winid, function()
		return vim.fn.line("w0")
	end)
	local current_handle_row = math.floor(current_topline * line_to_row_ratio)
	local max_handle_row = math.max(math.floor(max_topline * line_to_row_ratio), 0)

	return {
		bufnr = bufnr,
		height = height,
		total_lines = total_lines,
		max_topline = max_topline,
		handle_height = handle_height,
		current_handle_row = math.min(current_handle_row, max_handle_row),
		max_handle_row = max_handle_row,
	}
end

local function mouse_row_for_window(mouse, winid)
	local winnr = vim.fn.win_id2win(winid)
	if winnr == 0 then
		return mouse.winrow
	end

	local window_position = vim.fn.win_screenpos(winnr)
	return mouse.screenrow - window_position[1] + 1
end

local function set_scrollbar_view(winid, topline, geometry)
	local cursor = vim.api.nvim_win_get_cursor(winid)
	local last_visible_line = math.min(topline + geometry.height - 1, geometry.total_lines)
	local scrolloff = math.min(vim.wo[winid].scrolloff, math.floor((last_visible_line - topline) / 2))
	local first_cursor_line = topline + scrolloff
	local last_cursor_line = last_visible_line - scrolloff
	local cursor_line = math.max(first_cursor_line, math.min(cursor[1], last_cursor_line))
	local line = vim.api.nvim_buf_get_lines(geometry.bufnr, cursor_line - 1, cursor_line, false)[1] or ""
	local cursor_col = math.min(cursor[2], #line)

	-- Keep the cursor inside the requested viewport so winrestview can set an exact topline.
	vim.api.nvim_win_set_cursor(winid, { cursor_line, cursor_col })
	vim.api.nvim_win_call(winid, function()
		vim.fn.winrestview({ topline = topline })
	end)
end

local function schedule_scrollbar_view(winid, topline)
	pending_scrollbar_view = { winid = winid, topline = topline }
	if scrollbar_view_scheduled then
		return
	end

	scrollbar_view_scheduled = true
	vim.schedule(function()
		scrollbar_view_scheduled = false
		local pending = pending_scrollbar_view
		pending_scrollbar_view = nil
		if not pending or not vim.api.nvim_win_is_valid(pending.winid) then
			return
		end

		local geometry = scrollbar_geometry(pending.winid)
		local target_topline = math.max(1, math.min(pending.topline, geometry.max_topline))
		set_scrollbar_view(pending.winid, target_topline, geometry)
		vim.api.nvim_win_call(pending.winid, function()
			require("scrollbar").render()
		end)
	end)
end

local function scroll_to_mouse_position(winid, mouse)
	if not vim.api.nvim_win_is_valid(winid) then
		return
	end

	local geometry = scrollbar_geometry(winid)
	local mouse_row = mouse_row_for_window(mouse, winid)
	local desired_handle_row = math.max(0, math.min(mouse_row - 1 - scrollbar_drag.offset, geometry.max_handle_row))
	local topline = 1
	if geometry.max_handle_row > 0 then
		local ratio = desired_handle_row / geometry.max_handle_row
		topline = math.floor(ratio * (geometry.max_topline - 1)) + 1
	end

	schedule_scrollbar_view(winid, topline)
end

local function begin_scrollbar_drag()
	local mouse = vim.fn.getmousepos()
	if not scrollbar_is_clickable(mouse) then
		reset_scrollbar_drag()
		return "<LeftMouse>"
	end

	local geometry = scrollbar_geometry(mouse.winid)
	local mouse_row = mouse_row_for_window(mouse, mouse.winid) - 1
	local handle_last_row = geometry.current_handle_row + geometry.handle_height - 1
	if mouse_row >= geometry.current_handle_row and mouse_row <= handle_last_row then
		scrollbar_drag.offset = mouse_row - geometry.current_handle_row
	else
		scrollbar_drag.offset = math.floor((geometry.handle_height - 1) / 2)
	end

	scrollbar_drag.winid = mouse.winid
	scrollbar_drag.previous_mousemoveevent = vim.o.mousemoveevent
	vim.o.mousemoveevent = true
	scroll_to_mouse_position(mouse.winid, mouse)
	return ""
end

local function continue_scrollbar_drag(fallback_key)
	if not scrollbar_drag.winid or not vim.api.nvim_win_is_valid(scrollbar_drag.winid) then
		reset_scrollbar_drag()
		return fallback_key
	end

	local mouse = vim.fn.getmousepos()
	scroll_to_mouse_position(scrollbar_drag.winid, mouse)
	return ""
end

local function end_scrollbar_drag()
	if not scrollbar_drag.winid then
		return "<LeftRelease>"
	end

	reset_scrollbar_drag()
	return ""
end

vim.keymap.set("n", "<LeftMouse>", begin_scrollbar_drag, { expr = true, desc = "Start scrollbar drag" })
vim.keymap.set({ "n", "x", "s" }, "<LeftDrag>", function()
	return continue_scrollbar_drag("<LeftDrag>")
end, { expr = true, desc = "Drag scrollbar" })
vim.keymap.set({ "n", "x", "s" }, "<MouseMove>", function()
	return continue_scrollbar_drag("<MouseMove>")
end, { expr = true, desc = "Track scrollbar drag" })
vim.keymap.set({ "n", "x", "s" }, "<LeftRelease>", end_scrollbar_drag, {
	expr = true,
	desc = "End scrollbar drag",
})
