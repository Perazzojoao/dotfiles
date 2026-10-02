-- Exercise the configured explorer action, real pickers, inputs, and file renderer.
local config = vim.fn.getcwd()
vim.opt.runtimepath:prepend(config)
vim.opt.packpath:append(vim.fn.expand("~/.local/share/nvim/site"))
for _, plugin in ipairs({ "snacks.nvim", "template.nvim", "nvim-web-devicons" }) do
	vim.cmd.packadd(plugin)
end
vim.g.mapleader = " "
vim.o.lines, vim.o.columns = 40, 120
vim.o.hidden = true
local package_add = vim.pack.add
vim.pack.add = function() end
require("plugin.01-snack")
require("plugin.templates")
vim.pack.add = package_add

local sandbox = vim.fn.tempname()
local project = sandbox .. "/MyApp"
vim.fn.mkdir(project .. "/Existing/Empty", "p")
vim.fn.writefile({ "<Project />" }, project .. "/MyApp.csproj")
vim.fn.writefile({ "namespace MyApp;" }, project .. "/Main.cs")
vim.fn.writefile({ "original" }, project .. "/Existing/Empty/Seed.cs")
vim.api.nvim_set_current_dir(project)
vim.cmd.edit(project .. "/Main.cs")
vim.bo.filetype = "cs"
local main = vim.api.nvim_get_current_win()
local explorer = Snacks.explorer.open({ cwd = project, follow_file = false, watch = false, git_status = false })
local inputs, errors = {}, {}
local native_input, native_notify = Snacks.input, vim.notify
Snacks.input = function(options, callback)
	local window = native_input(options, callback)
	inputs[#inputs + 1] = { window = window, options = options }
	return window
end
vim.notify = function(message, level, options)
	if options and options.title == "Templates" and level == vim.log.levels.ERROR then
		errors[#errors + 1] = message
	else
		native_notify(message, level, options)
	end
end

local done, cases = false, 0
local function finish(err)
	if done then return end
	done = true
	Snacks.input, vim.notify = native_input, native_notify
	for _, picker in ipairs(Snacks.picker.get()) do picker:close() end
	vim.fn.delete(sandbox, "rf")
	if err then
		io.stderr:write(err .. "\n")
		vim.cmd("cquit 1")
	else
		print("TEMPLATES_EXPLORER_OK " .. cases .. " cases")
		vim.cmd("qall!")
	end
end
local function later(callback, delay)
	vim.defer_fn(function()
		if done then return end
		local ok, err = xpcall(callback, debug.traceback)
		if not ok then finish(err) end
	end, delay or 180)
end
local function template_picker()
	for _, picker in ipairs(Snacks.picker.get()) do
		if (picker.opts.title or ""):find("Templates ·", 1, true) then return picker end
	end
	error("Template picker not open")
end
local function select_template(picker)
	for index, item in ipairs(picker:items()) do
		if item.text == "csharp/class" then
			picker.list:move(index, true)
			picker:action("confirm")
			return
		end
	end
	error("Class template missing")
end
local scenarios = {
	{ name = "T na raiz abre diretamente o input e cria na raiz", target = "", value = "RootFromTree", path = "/RootFromTree.cs", namespace = "MyApp" },
	{ name = "pasta selecionada mantém subdiretórios e namespace", target = "/Existing/Empty", value = "Entities/FromTree", path = "/Existing/Empty/Entities/FromTree.cs", namespace = "MyApp.Existing.Empty.Entities" },
	{ name = "arquivo selecionado usa a pasta que o contém", target = "/Existing/Empty/Seed.cs", value = "SiblingFromTree", path = "/Existing/Empty/SiblingFromTree.cs", namespace = "MyApp.Existing.Empty" },
	{ name = "Alt-A preserva o destino do explorer", target = "/Existing/Empty", value = "ToggledFromTree", path = "/Existing/Empty/ToggledFromTree.cs", namespace = "MyApp.Existing.Empty", toggle = true },
	{ name = "cancelar templates mantém explorer e não abre input", target = "/Existing/Empty", cancel_picker = true },
	{ name = "cancelar input não cria arquivos nem pastas", target = "/Existing/Empty", cancel_input = true },
	{ name = "arquivo existente é preservado", target = "/Existing/Empty", value = "Seed", error = true },
	{ name = "caminho sem nome de arquivo é recusado", target = "/Existing/Empty", value = "InvalidFolder/", error = true },
}
local width, sidebar
local function run(index)
	local scenario = scenarios[index]
	if not scenario then finish(); return end
	vim.cmd.stopinsert()
	local target = project .. scenario.target
	require("snacks.explorer.tree"):open(target)
	require("snacks.explorer.actions").update(explorer, { target = target, refresh = true })
	later(function()
		local found = false
		for position, item in ipairs(explorer:items()) do
			if item.file == target then
				explorer.list:move(position, true)
				found = true
				break
			end
		end
		assert(found, "Explorer item missing: " .. target)
		explorer.list.win:focus()
		local input_count, error_count = #inputs, #errors
		local mapping = vim.fn.maparg("T", "n", false, true)
		assert(mapping.buffer == 1 and type(mapping.callback) == "function", "T is not an explorer-local mapping")
		mapping.callback()
		local function complete()
			assert(not explorer.closed and vim.api.nvim_win_is_valid(main))
			assert(vim.api.nvim_win_get_width(sidebar) == width, "Explorer layout changed")
			assert(vim.api.nvim_win_call(main, vim.fn.getcwd) == project, "Main cwd changed")
			assert(vim.fn.readfile(project .. "/Existing/Empty/Seed.cs")[1] == "original")
			assert(not vim.uv.fs_stat(project .. "/Existing/Empty/InvalidFolder"))
			cases = cases + 1
			print("PASS " .. scenario.name)
			run(index + 1)
		end
		local function choose(picker)
			if scenario.cancel_picker then
				picker:close()
				later(function()
					assert(#inputs == input_count)
					complete()
				end)
				return
			end
			select_template(picker)
			later(function()
				assert(#inputs == input_count + 1, "Expected direct filename input")
				for _, active in ipairs(Snacks.picker.get()) do
					assert(not (active.opts.title or ""):find("Pastas do projeto", 1, true), "Unexpected folder picker")
				end
				local input = inputs[#inputs]
				local directory = scenario.target:match("%.cs$") and vim.fs.dirname(target) or target
				assert(input.options.completion == "file")
				local relative = vim.fs.relpath(project, directory)
				local label = (relative == "" or relative == ".") and ". (raiz)" or relative .. "/"
				assert(input.options.prompt == "Arquivo em " .. label .. " (.cs): ")
				assert(not input.options.prompt:find(sandbox, 1, true), "Input displays an absolute path")
				assert(vim.api.nvim_win_call(input.window.win, vim.fn.getcwd) == directory)
				if scenario.cancel_input then
					input.window:execute("cancel")
				else
					vim.api.nvim_buf_set_lines(input.window.buf, 0, -1, false, { scenario.value })
					input.window:execute("confirm")
				end
				later(function()
					assert(#errors == error_count + (scenario.error and 1 or 0), vim.inspect(errors))
					if scenario.path then
						local path = project .. scenario.path
						assert(vim.fn.readfile(path)[1] == "namespace " .. scenario.namespace .. ";")
						assert(vim.api.nvim_get_current_win() == main)
						assert(vim.api.nvim_buf_get_name(0) == path)
						assert(vim.api.nvim_get_mode().mode == "i")
						local visible = false
						for _, item in ipairs(explorer:items()) do if item.file == path then visible = true end end
						assert(visible, "Created file missing from explorer")
					end
					complete()
				end)
			end)
		end
		later(function()
			local picker = template_picker()
			if scenario.toggle then
				picker.input:set("class")
				picker:action("templates_toggle")
				later(function()
					local all = template_picker()
					assert(all.opts.title:find("todas", 1, true))
					assert(all.input.filter.pattern == "class")
					choose(all)
				end)
			else
				choose(picker)
			end
		end)
	end)
end
later(function()
	sidebar = explorer.list.win.win
	width = vim.api.nvim_win_get_width(sidebar)
	run(1)
end, 250)
later(function() error("Explorer template tests timed out") end, 20000)
