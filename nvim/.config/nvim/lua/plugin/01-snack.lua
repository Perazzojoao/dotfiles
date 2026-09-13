-- Snacks: loaded early (01- prefix) so its picker is available to other plugins.
vim.pack.add({
	{ src = "https://github.com/nvim-tree/nvim-web-devicons", version = "master" },
	"https://github.com/folke/snacks.nvim",
})

local function confirm_explorer_item_under_mouse(picker)
	local mouse = vim.fn.getmousepos()
	if mouse.winid ~= picker.list.win.win then
		return
	end

	local view = vim.api.nvim_win_call(mouse.winid, vim.fn.winsaveview)
	local row = mouse.line - view.topline + 1
	if row < 1 or row > picker.list:height() then
		return
	end

	picker.list:move(picker.list:row2idx(row), true, true)
	local item = picker.list:current()
	picker:action("confirm")

	if item and not item.dir then
		vim.schedule(function()
			if vim.api.nvim_win_is_valid(picker.main) then
				vim.api.nvim_set_current_win(picker.main)
			end
		end)
	end
end

---@type snacks.Config
require("snacks").setup({
	explorer = { enabled = true },
	picker = {
		enabled = true,
		sources = {
			files = {
				hidden = true,
				ignored = true,
				exclude = { ".git" },
			},
			explorer = {
				hidden = true,
				ignored = true,
				exclude = { ".git" },
				actions = {
					mouse_confirm = confirm_explorer_item_under_mouse,
				},
				win = {
					list = {
						keys = {
							["<LeftMouse>"] = "mouse_confirm",
							-- A double click includes the first-click action above.
							["<2-LeftMouse>"] = false,
						},
					},
				},
				layout = {
					layout = {
						width = 32,
						min_width = 32,
					},
				},
			},
		},
	},
	project = {
		dirs = {
			"~/github",
			"~/projects",
			"~/build",
			"~/Dev/Personal",
			"~/Dev/ProjPlan",
		},
	},
	indent = { enabled = true },
	notifier = { enabled = true },
	statuscolumn = { enabled = true },
	zen = { enabled = true },
})

local map = vim.keymap.set
map("n", "<leader>sh", function()
	Snacks.picker.help()
end, { desc = "[S]earch [H]elp" })
map("n", "<leader>sk", function()
	Snacks.picker.keymaps()
end, { desc = "[S]earch [K]eymaps" })
map("n", "<leader>sc", function()
	Snacks.picker.commands()
end, { desc = "[S]earch [C]ommands" })
map("n", "<leader>sf", function()
	Snacks.picker.files()
end, { desc = "[S]earch [F]iles" })
map("n", "<leader>fe", function()
	Snacks.explorer.open()
end, { desc = "[F]iles [E]xplorer open tree" })
map("n", "<leader>ff", function()
	Snacks.picker.smart()
end, { desc = "[S]earch [F]iles" })
map("n", "<leader>ss", function()
	Snacks.picker.pickers()
end, { desc = "[S]earch [S]elect Snacks" })
map({ "n", "x" }, "<leader>sw", function()
	Snacks.picker.grep_word()
end, { desc = "[S]earch current [W]ord" })
map("n", "<leader>fg", function()
	Snacks.picker.grep()
end, { desc = "[S]earch by [G]rep" })
map("n", "<leader>fp", function()
	Snacks.picker.projects()
end, { desc = "[S]earch [P]rojects" })
map("n", "<leader>sd", function()
	Snacks.picker.diagnostics()
end, { desc = "[S]earch [D]iagnostics" })
map("n", "<leader>sg", function()
	Snacks.picker.git_status()
end, { desc = "[S]earch [G]it status" })
map("n", "<leader>sr", function()
	Snacks.picker.resume()
end, { desc = "[S]earch [R]esume" })
map("n", "<leader>s.", function()
	Snacks.picker.recent()
end, { desc = '[S]earch Recent Files ("." for repeat)' })
map("n", "<leader><leader>", function()
	Snacks.picker.buffers()
end, { desc = "[ ] Find existing buffers" })
map("n", "<leader>/", function()
	Snacks.picker.lines({})
end, { desc = "[/] Fuzzily search in current buffer" })
map("n", "<leader>s/", function()
	Snacks.picker.grep_buffers()
end, { desc = "[S]earch [/] in Open Files" })
map("n", "<leader>sn", function()
	Snacks.picker.files({ cwd = vim.fn.stdpath("config") })
end, { desc = "[S]earch [N]eovim files" })
map("n", "<C-\\>", function()
	Snacks.zen()
end, { desc = "Toggle [Z]en mode" })
