-- Jupyter notebooks: editable Markdown view, Jupyter kernels, inline outputs,
-- and LSP features inside fenced code cells.
--
-- Keep Neovim's remote Python plugins isolated from project virtualenvs. The
-- environment is created during notebook setup and intentionally contains only
-- editor tooling (Jupytext, pynvim, and the Jupyter client libraries).
local notebook_python = vim.fn.expand("~/.virtualenvs/neovim-jupyter/bin/python")
if vim.fn.executable(notebook_python) == 1 then
	vim.g.python3_host_prog = notebook_python
	vim.env.PATH = vim.fn.fnamemodify(notebook_python, ":h") .. ":" .. vim.env.PATH
end

vim.pack.add({
	"https://github.com/GCBallesteros/jupytext.nvim",
	"https://github.com/benlubas/molten-nvim",
	"https://github.com/3rd/image.nvim",
	"https://github.com/jmbuhr/otter.nvim",
	"https://github.com/quarto-dev/quarto-nvim",
})

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "Jupyter notebooks" })
end

local function command_is_available(command)
	return vim.fn.exists(":" .. command) == 2
end

local function has_command(command)
	return vim.fn.executable(command) == 1
end

local function image_backend()
	if vim.env.KITTY_WINDOW_ID and vim.env.KITTY_WINDOW_ID ~= "" then
		return "kitty"
	end

	if has_command("ueberzugpp") then
		return "ueberzug"
	end

	if vim.env.TERM and vim.env.TERM:find("sixel", 1, true) then
		return "sixel"
	end
end

local function setup_image_output()
	local backend = image_backend()
	vim.g.molten_image_provider = backend and "image.nvim" or "none"

	if not backend then
		return
	end

	if not (has_command("magick") or has_command("convert")) then
		return
	end

	local ok, image = pcall(require, "image")
	if not ok then
		return
	end

	image.setup({
		backend = backend,
		processor = "magick_cli",
		integrations = {
			markdown = {
				enabled = true,
				filetypes = { "markdown", "quarto" },
				only_render_image_at_cursor = true,
				only_render_image_at_cursor_mode = "popup",
			},
		},
	})
end

-- These must be assigned before Molten's remote Python host starts.
vim.g.molten_auto_open_output = false
vim.g.molten_wrap_output = true
vim.g.molten_virt_text_output = true
vim.g.molten_virt_lines_off_by_1 = true
vim.g.molten_output_virt_lines = true
vim.g.molten_image_location = "both"
setup_image_output()

local jupytext_ok, jupytext = pcall(require, "jupytext")
if jupytext_ok then
	-- Markdown keeps narrative cells readable; render-markdown is already part
	-- of this configuration and renders that representation in the buffer.
	jupytext.setup({
		style = "markdown",
		output_extension = "md",
		force_ft = "markdown",
	})
end

local quarto_ok, quarto = pcall(require, "quarto")
if quarto_ok then
	quarto.setup({
		lspFeatures = {
			enabled = true,
			chunks = "all",
			languages = { "python", "r", "julia", "bash", "lua", "javascript", "typescript" },
			diagnostics = { enabled = true, triggers = { "BufWritePost" } },
			completion = { enabled = true },
		},
		codeRunner = {
			enabled = true,
			default_method = "molten",
			never_run = { "yaml" },
		},
	})
end

local function run_molten(command, available_command)
	return function()
		available_command = available_command or command
		if not command_is_available(available_command) then
			notify(("%s is unavailable. Run :UpdateRemotePlugins after installing Molten."):format(available_command), vim.log.levels.ERROR)
			return
		end
		vim.cmd(command)
	end
end

local function run_quarto(method)
	return function()
		local ok, runner = pcall(require, "quarto.runner")
		if not ok then
			notify("quarto-nvim is not installed yet. Restart Neovim after the plugin download.", vim.log.levels.ERROR)
			return
		end
		runner[method]()
	end
end

local function set_notebook_keymaps(bufnr)
	local options = { buffer = bufnr, silent = true }
	local map = vim.keymap.set

	map("n", "<leader>ni", run_molten("MoltenInit"), vim.tbl_extend("force", options, { desc = "[N]otebook [I]nitialize kernel" }))
	map("n", "<leader>nr", run_quarto("run_cell"), vim.tbl_extend("force", options, { desc = "[N]otebook [R]un cell" }))
	map("n", "<leader>na", run_quarto("run_above"), vim.tbl_extend("force", options, { desc = "[N]otebook run cell and [A]bove" }))
	map("n", "<leader>nA", run_quarto("run_all"), vim.tbl_extend("force", options, { desc = "[N]otebook run [A]ll cells" }))
	map("n", "<leader>nl", run_quarto("run_line"), vim.tbl_extend("force", options, { desc = "[N]otebook run [L]ine" }))
	map("x", "<leader>nr", run_quarto("run_range"), vim.tbl_extend("force", options, { desc = "[N]otebook [R]un selection" }))
	map("n", "<leader>no", run_molten("noautocmd MoltenEnterOutput", "MoltenEnterOutput"), vim.tbl_extend("force", options, { desc = "[N]otebook open [O]utput" }))
	map("n", "<leader>nh", run_molten("MoltenHideOutput"), vim.tbl_extend("force", options, { desc = "[N]otebook [H]ide output" }))
	map("n", "<leader>nx", run_molten("MoltenInterrupt"), vim.tbl_extend("force", options, { desc = "[N]otebook interrupt kernel" }))
	map("n", "<leader>nR", run_molten("MoltenRestart!"), vim.tbl_extend("force", options, { desc = "[N]otebook [R]estart kernel and clear outputs" }))
	map("n", "<leader>nd", run_molten("MoltenDelete"), vim.tbl_extend("force", options, { desc = "[N]otebook [D]elete cell output" }))
	map("n", "<leader>ne", run_molten("MoltenExportOutput!"), vim.tbl_extend("force", options, { desc = "[N]otebook [E]xport outputs" }))
end

local function notebook_kernel(path)
	local ok, content = pcall(vim.fn.readfile, path)
	if not ok then
		return nil
	end

	local decoded_ok, notebook = pcall(vim.json.decode, table.concat(content, "\n"))
	if not decoded_ok then
		return nil
	end

	return notebook.metadata and notebook.metadata.kernelspec and notebook.metadata.kernelspec.name or nil
end

local function import_notebook_outputs(event)
	if vim.b[event.buf].notebook_outputs_imported or not command_is_available("MoltenImportOutput") then
		return
	end

	vim.b[event.buf].notebook_outputs_imported = true
	vim.schedule(function()
		if not vim.api.nvim_buf_is_valid(event.buf) then
			return
		end

		local kernel = notebook_kernel(event.file)
		local available_ok, available = pcall(vim.fn.MoltenAvailableKernels)
		if kernel and available_ok and vim.tbl_contains(available, kernel) then
			vim.cmd({ cmd = "MoltenInit", args = { kernel } })
		else
			-- Molten asks for a kernel when the notebook's kernel is not installed.
			vim.cmd("MoltenInit")
		end
		vim.cmd("MoltenImportOutput")
	end)
end

local notebook_group = vim.api.nvim_create_augroup("jupyter-notebooks", { clear = true })
vim.api.nvim_create_autocmd("BufEnter", {
	group = notebook_group,
	pattern = "*.ipynb",
	callback = function(event)
		set_notebook_keymaps(event.buf)
		if quarto_ok then
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(event.buf) then
					vim.api.nvim_buf_call(event.buf, quarto.activate)
				end
			end)
		end
		import_notebook_outputs(event)
	end,
})

local function python_modules_are_available()
	local python = vim.g.python3_host_prog or vim.fn.exepath("python3")
	if python == "" or vim.fn.executable(python) == 0 then
		return false
	end

	vim.fn.system({ python, "-c", "import jupyter_client, nbformat, pynvim" })
	return vim.v.shell_error == 0
end

vim.api.nvim_create_user_command("NotebookHealth", function()
	local checks = {
		{ "jupytext CLI", has_command("jupytext") },
		{ "jupyter CLI", has_command("jupyter") },
		{ "Python modules (pynvim, jupyter_client, nbformat)", python_modules_are_available() },
		{ "ImageMagick", has_command("magick") or has_command("convert") },
		{ "image backend", image_backend() ~= nil },
		{ "Molten remote plugin", command_is_available("MoltenInit") },
	}
	local lines = {}
	for _, check in ipairs(checks) do
		table.insert(lines, ("%s %s"):format(check[2] and "✓" or "✗", check[1]))
	end
	notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, { desc = "Check Jupyter notebook dependencies" })

local default_notebook = {
	cells = {
		{ cell_type = "markdown", metadata = {}, source = { "" } },
	},
	metadata = {
		kernelspec = { display_name = "Python 3", language = "python", name = "python3" },
		language_info = { name = "python", file_extension = ".py", mimetype = "text/x-python" },
	},
	nbformat = 4,
	nbformat_minor = 5,
}

vim.api.nvim_create_user_command("NewNotebook", function(options)
	local path = options.args:match("%.ipynb$") and options.args or options.args .. ".ipynb"
	if vim.uv.fs_stat(path) then
		notify(("Notebook already exists: %s"):format(path), vim.log.levels.ERROR)
		return
	end

	local parent = vim.fn.fnamemodify(path, ":h")
	if vim.fn.mkdir(parent, "p") == 0 and vim.fn.isdirectory(parent) == 0 then
		notify(("Could not create directory: %s"):format(parent), vim.log.levels.ERROR)
		return
	end

	vim.fn.writefile({ vim.json.encode(default_notebook) }, path)
	vim.cmd.edit(vim.fn.fnameescape(path))
end, { nargs = 1, complete = "file", desc = "Create and open a Python Jupyter notebook" })
