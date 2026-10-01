-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Shorten function name
local keymap = vim.keymap.set

local function copy_file_context(use_selection)
	local buffer = vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(buffer)

	if filename == "" then
		vim.notify("Não foi possível copiar contexto: o buffer atual não é um arquivo.", vim.log.levels.WARN)
		return
	end

	local start_line
	local end_line

	if use_selection then
		-- Visual marks describe the previous selection until Visual mode ends.
		start_line = vim.fn.line("v")
		end_line = vim.api.nvim_win_get_cursor(0)[1]
	else
		start_line = vim.api.nvim_win_get_cursor(0)[1]
		end_line = start_line
	end

	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local relative_path = vim.fn.fnamemodify(filename, ":.")
	local context_lines = { string.format("%s:%d-%d", relative_path, start_line, end_line) }

	vim.list_extend(context_lines, vim.api.nvim_buf_get_lines(buffer, start_line - 1, end_line, false))

	vim.fn.setreg("+", context_lines, "V")
	vim.notify(string.format("Contexto copiado: %s:%d-%d", relative_path, start_line, end_line))
end

local function active_listed_buffers()
	local buffers = {}

	for _, buffer in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
		if vim.api.nvim_buf_is_loaded(buffer.bufnr) then
			table.insert(buffers, buffer)
		end
	end

	return buffers
end

local function save_buffer(bufnr)
	if vim.bo[bufnr].modified then
		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd.write()
		end)
	end
end

local function save_and_close_current_buffer()
	if #active_listed_buffers() == 1 then
		vim.cmd.wq()
		return
	end

	local current = vim.api.nvim_get_current_buf()
	save_buffer(current)
	vim.api.nvim_buf_delete(current, { force = false })
end

local function save_and_close_other_buffers()
	local current = vim.api.nvim_get_current_buf()

	for _, buffer in ipairs(active_listed_buffers()) do
		if buffer.bufnr ~= current then
			save_buffer(buffer.bufnr)
			vim.api.nvim_buf_delete(buffer.bufnr, { force = false })
		end
	end
end

local function close_current_buffer(force)
	if #active_listed_buffers() == 1 then
		vim.cmd(force and "q!" or "q")
		return
	end

	vim.api.nvim_buf_delete(vim.api.nvim_get_current_buf(), { force = force })
end

local function close_current_buffer_safely()
	close_current_buffer(false)
end

local function force_close_current_buffer()
	close_current_buffer(true)
end

local function is_regular_window(win)
	return win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == ""
end

local function managed_split()
	local split = vim.t.managed_buffer_split

	if type(split) ~= "table" or not is_regular_window(split.left) or not is_regular_window(split.right) then
		vim.t.managed_buffer_split = nil
		return nil
	end

	return split
end

local function next_listed_buffer(current)
	for _, buffer in ipairs(active_listed_buffers()) do
		if buffer.bufnr ~= current then
			return buffer.bufnr
		end
	end

	return current
end

local function set_window_buffer(win, bufnr)
	if vim.api.nvim_win_get_buf(win) ~= bufnr then
		vim.api.nvim_win_set_buf(win, bufnr)
	end
end

local function create_managed_split(direction)
	local current_win = vim.api.nvim_get_current_win()
	local current_buf = vim.api.nvim_get_current_buf()
	local other_buf = next_listed_buffer(current_buf)
	local left_win
	local right_win

	if direction == "right" then
		vim.cmd("rightbelow vsplit")
		right_win = vim.api.nvim_get_current_win()
		left_win = current_win
		set_window_buffer(left_win, other_buf)
	else
		vim.cmd("leftabove vsplit")
		left_win = vim.api.nvim_get_current_win()
		right_win = current_win
		set_window_buffer(right_win, other_buf)
	end

	set_window_buffer(direction == "right" and right_win or left_win, current_buf)
	vim.t.managed_buffer_split = { left = left_win, right = right_win }
end

local function move_buffer_to_split(direction)
	local current_win = vim.api.nvim_get_current_win()
	local current_buf = vim.api.nvim_get_current_buf()
	local split = managed_split()

	if not split then
		create_managed_split(direction)
		return
	end

	local target_win = split[direction]
	local other_win = direction == "right" and split.left or split.right
	local target_buf = vim.api.nvim_win_get_buf(target_win)

	set_window_buffer(target_win, current_buf)

	if current_win == other_win then
		set_window_buffer(other_win, target_buf)
	elseif current_win ~= target_win then
		set_window_buffer(current_win, target_buf)
	end

	vim.api.nvim_set_current_win(target_win)
end

local function close_current_split_and_keep_buffer_focused()
	local current_win = vim.api.nvim_get_current_win()
	local current_buf = vim.api.nvim_get_current_buf()
	local target_win

	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if win ~= current_win and is_regular_window(win) then
			target_win = win
			break
		end
	end

	if not target_win then
		return
	end

	set_window_buffer(target_win, current_buf)
	vim.t.managed_buffer_split = nil

	local ok = pcall(vim.api.nvim_win_close, current_win, false)
	if ok and vim.api.nvim_win_is_valid(target_win) then
		vim.api.nvim_set_current_win(target_win)
	end
end

-- Restart config --
keymap("n", "<leader>re", "<cmd>restart<cr>", { desc = "Restart config :restart)" })

-- Normal --
-- Quit and save
keymap(
	"n",
	"<leader>w",
	save_and_close_current_buffer,
	{ desc = "Close and save buffer", noremap = true, silent = true }
)
keymap("n", "<leader>kw", ":wa<CR>:qa<CR>", { desc = "Close and save all Windows", noremap = true, silent = true })
keymap(
	"n",
	"<leader>ko",
	save_and_close_other_buffers,
	{ desc = "Close and save other buffers", noremap = true, silent = true }
)
keymap("n", "<leader>kf", force_close_current_buffer, { desc = "Force close buffer", noremap = true, silent = true })
keymap("n", "<leader>q", close_current_buffer_safely, { desc = "Close buffer", noremap = true, silent = true })

-- Saving file
keymap("n", "<C-s>", ":w<CR>", { noremap = true, silent = true })
keymap("i", "<C-s>", "<C-o><cmd>write<CR><Esc>", { noremap = true, silent = true })

-- Split window
keymap("n", "<leader>l", function()
	move_buffer_to_split("right")
end, { desc = "Move Buffer to Right Split", noremap = true, silent = true })
keymap(
	"n",
	"<leader>h",
	close_current_split_and_keep_buffer_focused,
	{ desc = "Close Split and Focus Buffer", noremap = true, silent = true }
)

-- Tabs
keymap("n", "<leader>tt", ":tabedit<CR>", { desc = "", noremap = true, silent = true })
keymap("n", "<tab>", ":tabnext<CR>", { noremap = true, silent = true })
keymap("n", "<s-tab>", ":tabprev<CR>", { noremap = true, silent = true })

-- Better window navigation
keymap("n", "<C-h>", ":wincmd h<CR>", { noremap = true, silent = true })
keymap("n", "<C-j>", ":wincmd j<CR>", { noremap = true, silent = true })
keymap("n", "<C-k>", ":wincmd k<CR>", { noremap = true, silent = true })
keymap("n", "<C-l>", ":wincmd l<CR>", { noremap = true, silent = true })

-- Resize with arrows
keymap("n", "<C-Up>", ":resize -2<CR>", { noremap = true, silent = true })
keymap("n", "<C-Down>", ":resize +2<CR>", { noremap = true, silent = true })
keymap("n", "<C-Left>", ":vertical resize -2<CR>", { noremap = true, silent = true })
keymap("n", "<C-Right>", ":vertical resize +2<CR>", { noremap = true, silent = true })

-- Navigate buffers
keymap("n", "<A-l>", ":bnext<CR>", { noremap = true, silent = true })
keymap("n", "<A-h>", ":bprevious<CR>", { noremap = true, silent = true })

-- Move text up and down
keymap("n", "<S-j>", ":m .+1<CR>==", { noremap = true, silent = true })
keymap("n", "<S-k>", ":m .-2<CR>==", { noremap = true, silent = true })

-- Duplicate line
keymap("n", "<A-j>", "yyp", { noremap = true, silent = true })
keymap("n", "<A-k>", "yyP", { noremap = true, silent = true })

-- Copy file context for AI prompts
keymap("n", "<leader>y", function()
	copy_file_context(false)
end, { desc = "Copy current line with file context", noremap = true, silent = true })

-- Adding new lines
keymap("n", "<CR>", "o<C-c>", { noremap = true, silent = true })
keymap("n", "<S-CR>", "O<C-c>", { noremap = true, silent = true })

-- Visual --
-- Stay in indent mode
keymap("v", "<", "<gv^", { noremap = true, silent = true })
keymap("v", ">", ">gv^", { noremap = true, silent = true })

-- Move text up and down
keymap("v", "<S-j>", ":m '>+1<CR>gv=gv", { noremap = true, silent = true })
keymap("v", "<S-k>", ":m '<-2<CR>gv=gv", { noremap = true, silent = true })
keymap("v", "p", '"_dP', { noremap = true, silent = true })

-- Duplicate text up and down
keymap("v", "<A-j>", ":t'>+1<CR>gv=gv", { noremap = true, silent = true })
keymap("v", "<A-k>", ":t'<-1<CR>gv=gv", { noremap = true, silent = true })

keymap("x", "<leader>y", function()
	copy_file_context(true)
end, { desc = "Copy selection with file context", noremap = true, silent = true })

-- Insert Mode
-- Better navigation
keymap("i", "<A-k>", "<Up>", { noremap = true, silent = true })
keymap("i", "<A-j>", "<Down>", { noremap = true, silent = true })
keymap("i", "<A-h>", "<Left>", { noremap = true, silent = true })
keymap("i", "<A-l>", "<Right>", { noremap = true, silent = true })

-- Deleting
keymap("i", "<C-h>", "<Backspace>", { noremap = true, silent = true })
keymap("i", "<C-l>", "<Delete>", { noremap = true, silent = true })
keymap("i", "<C-BS>", function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local prefix = vim.api.nvim_get_current_line():sub(1, cursor[2])

	if cursor[2] == 0 then
		return ""
	end
	if prefix:match("^%s*$") then
		return "<C-u>"
	end

	return "<C-w>"
end, { desc = "Delete word backward", expr = true, noremap = true, replace_keycodes = true, silent = true })
keymap("i", "<C-Delete>", function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()

	if cursor[2] >= #line then
		return ""
	end

	return "<C-o>dw"
end, { desc = "Delete word forward", expr = true, noremap = true, replace_keycodes = true, silent = true })

-- General --
-- Custom commands
keymap("n", "ç", "%", { noremap = true, silent = true })
keymap("x", "p", [["_dP]], { desc = "Paste over selection without losing yanked text" })
keymap({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete without yanking" })
keymap("n", "<C-c>", ":nohl<CR>", { desc = "Clear search highlighting", silent = true })
-- keymap("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Replace word cursor is on globally" })

-- native undotree
keymap("n", "<leader>u", function()
	vim.cmd.packadd("nvim.undotree")
	require("undotree").open()
end, { desc = "Toggle Builtin Undotree" })
