local M = {}
local languages = require("templates.languages")
local catalog = require("templates.catalog")

local function notify(message)
	vim.notify(message, vim.log.levels.ERROR, { title = "Templates" })
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
	end
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
				Snacks.input(
					{ prompt = "Caminho do arquivo (" .. item.extension .. "): ", completion = "file" },
					function(value)
						create(item, value, context)
					end
				)
			end)
		end,
	})
end

function M.start(argument)
	if argument and argument ~= "all" and not languages.registry[argument] then
		notify("Linguagem desconhecida: " .. argument)
		return
	end
	local context = {
		cwd = vim.fn.getcwd(),
		window = vim.api.nvim_get_current_win(),
		language = argument ~= "all" and argument or languages.for_filetype(vim.bo.filetype),
	}
	return M.open(context, argument == "all" or not context.language)
end

return M
