local M = {}
local languages = require("templates.languages")
local catalog = require("templates.catalog")

local function notify(message)
	vim.notify(message, vim.log.levels.ERROR, { title = "Templates" })
end

local function project_root(path, fallback)
	return vim.fs.root(path, function(name)
		return vim.tbl_contains({ ".git", "package.json", "go.mod", "pom.xml", "build.gradle", "build.gradle.kts" }, name)
			or name:match("%.csproj$") ~= nil
			or name:match("%.slnx?$") ~= nil
	end) or fallback
end

local function create(item, value, context)
	if not value or vim.trim(value) == "" then
		return
	end
	local ok, result, err = pcall(require("templates.files").create, item, value, context)
	if not ok then
		notify(tostring(result))
	elseif err and err.root_required then
		Snacks.input(
			{ prompt = "Pasta raiz do projeto C#: ", completion = "dir", default = context.cwd },
			function(root)
				if root and vim.trim(root) ~= "" then
					create(item, value, vim.tbl_extend("force", context, { root = root }))
				end
			end
		)
	elseif err then
		notify(err.message)
	elseif result and context.on_created then
		context.on_created(result)
	end
end

local function input_filename(item, directory, context)
	return Snacks.input({
		prompt = "Arquivo em " .. directory.text .. " (" .. item.extension .. "): ",
		completion = "file",
		win = {
			on_win = function(window)
				vim.api.nvim_win_call(window.win, function()
					vim.cmd.lcd({ args = { directory.directory } })
				end)
			end,
		},
	}, function(value)
		if value and vim.trim(value) ~= "" then
			local path = require("templates.files").path(value, directory.directory)
			create(item, value:match("/$") and path .. "/" or path, context)
		end
	end)
end

local function select_directory(item, context)
	return Snacks.picker({
		title = "Pastas do projeto · " .. context.cwd,
		cwd = context.cwd,
		format = "text",
		layout = { preset = "select" },
		finder = function()
			return function(add)
				add({ text = ". (raiz)", directory = context.cwd })
				for path, kind in vim.fs.dir(context.cwd, {
					depth = math.huge,
					skip = function(path)
						return vim.fs.basename(path) ~= ".git"
					end,
				}) do
					if kind == "directory" and vim.fs.basename(path) ~= ".git" then
						add({ text = path .. "/", directory = vim.fs.joinpath(context.cwd, path) })
					end
				end
			end
		end,
		confirm = function(picker, directory)
			if not directory then
				return
			end
			picker:close()
			vim.schedule(function()
				input_filename(item, directory, context)
			end)
		end,
	})
end

function M.open(context, all, pattern)
	local language = not all and context.language or nil
	local title = "Templates · " .. (language or "todas") .. " · Alt-A: alternar linguagens"
	return Snacks.picker({
		title = title,
		cwd = require("template").temp_dir,
		items = catalog.list(language),
		pattern = pattern or "",
		show_empty = true,
		format = "text",
		preview = "file",
		actions = {
			templates_toggle = function(picker)
				local current_pattern = picker.input.filter.pattern
				picker:close()
				vim.schedule(function()
					M.open(context, not all, current_pattern)
				end)
			end,
		},
		win = {
			input = { keys = { ["<A-a>"] = { "templates_toggle", mode = { "n", "i" } } } },
			list = { keys = { ["<A-a>"] = "templates_toggle" } },
		},
		confirm = function(picker, item)
			if not item then
				return
			end
			picker:close()
			vim.schedule(function()
				if context.directory then
					local relative = vim.fs.relpath(context.cwd, context.directory) or context.directory
					local label = (relative == "" or relative == ".") and ". (raiz)" or relative .. "/"
					input_filename(item, { text = label, directory = context.directory }, context)
				else
					select_directory(item, context)
				end
			end)
		end,
	})
end

function M.start(argument)
	if argument and argument ~= "all" and not languages.registry[argument] then
		notify("Linguagem desconhecida: " .. argument)
		return
	end
	local cwd = vim.fn.getcwd()
	local filename = vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) or ""
	local root = project_root(filename ~= "" and filename or cwd, cwd)
	local context = {
		cwd = root or cwd,
		window = vim.api.nvim_get_current_win(),
		language = argument ~= "all" and argument or languages.for_filetype(vim.bo.filetype),
	}
	return M.open(context, argument == "all" or not context.language)
end

function M.from_explorer(explorer)
	local directory = explorer:dir()
	local window = explorer.main
	local item = explorer:current()
	local filetype = item and not item.dir and vim.filetype.match({ filename = item.file })
		or vim.bo[vim.api.nvim_win_get_buf(window)].filetype
	local context = {
		cwd = project_root(directory, explorer:cwd()),
		directory = directory,
		window = window,
		language = languages.for_filetype(filetype),
		on_created = function(result)
			if explorer.closed then
				return
			end
			require("snacks.explorer.tree"):refresh(result.path)
			local current_window = vim.api.nvim_get_current_win()
			require("snacks.explorer.actions").update(explorer, { target = result.path, refresh = true })
			-- Searching in the explorer can focus its list during refresh.
			if vim.api.nvim_win_is_valid(current_window) then
				vim.api.nvim_set_current_win(current_window)
			end
		end,
	}
	return M.open(context, not context.language)
end

return M
