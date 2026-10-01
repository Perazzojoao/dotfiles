-- Event-driven checks: do not nest vim.wait while reopening picker windows.
local config = vim.fn.getcwd()
vim.opt.runtimepath:prepend(config)
vim.opt.packpath:append(vim.fn.expand("~/.local/share/nvim/site"))
vim.cmd("packadd snacks.nvim")
vim.cmd("packadd template.nvim")
vim.g.mapleader = " "
vim.o.lines, vim.o.columns = 40, 120
vim.o.hidden = true
require("snacks").setup({ picker = { enabled = true }, input = { enabled = true } })
-- The plugin is already loaded; keep installation out of isolated test data.
local package_add = vim.pack.add
vim.pack.add = function() end
require("plugin.templates")
vim.pack.add = package_add
local sandbox = vim.fn.tempname()
local project = sandbox .. "/MyApp"
vim.fn.mkdir(project, "p")
vim.fn.writefile({ "<Project />" }, project .. "/MyApp.csproj")
vim.fn.mkdir(project .. "/Existing/Empty", "p")
vim.fn.mkdir(project .. "/.Hidden", "p")
vim.fn.mkdir(project .. "/.git/objects", "p")
vim.api.nvim_set_current_dir(project)
vim.bo.filetype = "cs"

local inputs, errors = {}, {}
local native_input = Snacks.input
Snacks.input = function(options, callback)
	local window = native_input(options, callback)
	inputs[#inputs + 1] = { window = window, options = options }
	return window
end
local native_notify = vim.notify
vim.notify = function(message, level, options)
	if options and options.title == "Templates" and level == vim.log.levels.ERROR then
		errors[#errors + 1] = message
	else
		native_notify(message, level, options)
	end
end

local done, cases = false, 0
local function finish(err)
	if done then
		return
	end
	done = true
	Snacks.input = native_input
	vim.notify = native_notify
	for _, picker in ipairs(Snacks.picker.get()) do
		picker:close()
	end
	for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
		if vim.startswith(vim.api.nvim_buf_get_name(buffer), sandbox .. "/") then
			vim.api.nvim_buf_delete(buffer, { force = true })
		end
	end
	vim.fn.delete(sandbox, "rf")
	if err then
		io.stderr:write(err .. "\n")
		vim.cmd("cquit 1")
	else
		print("TEMPLATES_PICKER_OK " .. cases .. " cases")
		vim.cmd("qa!")
	end
end

local function later(callback, delay)
	vim.defer_fn(function()
		if done then
			return
		end
		local ok, err = xpcall(callback, debug.traceback)
		if not ok then
			finish(err)
		end
	end, delay or 150)
end

local function check(name)
	cases = cases + 1
	print("PASS " .. name)
end

local function select(picker, id)
	assert(not picker:is_active(), "Picker ainda está processando")
	for index, entry in ipairs(picker:items()) do
		if entry.text == id then
			picker.list:move(index, true)
			picker:action("confirm")
			return
		end
	end
	error("Modelo não encontrado: " .. id)
end

local function answer(value, cancel)
	local input = assert(inputs[#inputs])
	assert(input.window:valid(), "Input não está aberto")
	if cancel then
		input.window:execute("cancel")
	else
		vim.api.nvim_buf_set_lines(input.window.buf, 0, -1, false, { value })
		input.window:execute("confirm")
	end
end

local function choose_directory(id, callback)
	local picker = assert(Snacks.picker.get()[1])
	assert(picker.opts.title:find("Pastas do projeto", 1, true))
	assert(picker.opts.cwd == project, "Raiz inesperada: " .. picker.opts.cwd .. "; cwd atual: " .. vim.fn.getcwd())
	select(picker, id)
	later(callback)
end

local function creation(kind, value, callback, directory)
	vim.bo.filetype = "cs"
	vim.cmd.stopinsert()
	local input_count = #inputs
	local picker = require("templates.picker").start()
	later(function()
		select(picker, "csharp/" .. kind)
		later(function()
			assert(#inputs == input_count, "Template abriu input antes da pasta")
			choose_directory(directory or ". (raiz)", function()
				local input = inputs[#inputs]
				assert(input.options.completion == "file")
				local base = directory and project .. "/" .. directory:gsub("/$", "") or project
				assert(vim.api.nvim_win_call(input.window.win, vim.fn.getcwd) == base)
				answer(value)
				later(callback)
			end)
		end)
	end)
end

local function root_cancel()
	-- Start the next creation from MyApp, rather than the external file just opened.
	vim.api.nvim_set_current_buf(vim.fn.bufnr(project .. "/Entities/Cliente.cs"))
	creation("class", sandbox .. "/Outside/Models/Cancelada", function()
		assert(inputs[#inputs].options.completion == "dir")
		answer(nil, true)
		later(function()
			assert(not vim.uv.fs_stat(sandbox .. "/Outside/Models/Cancelada.cs"))
			check("cancelamento da raiz não cria arquivo")
			assert(#errors == 0, vim.inspect(errors))
			finish()
		end)
	end)
end

local function root_confirm()
	vim.fn.mkdir(sandbox .. "/Outside", "p")
	creation("class", sandbox .. "/Outside/Models/Externa", function()
		assert(inputs[#inputs].options.prompt:find("raiz", 1, true))
		answer(sandbox .. "/Outside")
		later(function()
			local lines = vim.fn.readfile(sandbox .. "/Outside/Models/Externa.cs")
			assert(lines[1] == "namespace Outside.Models;")
			check("input de raiz para destino absoluto externo")
			root_cancel()
		end)
	end)
end

local function path_cancel()
	local picker = require("templates.picker").start("csharp")
	later(function()
		select(picker, "csharp/class")
		later(function()
			choose_directory(". (raiz)", function()
				local count = #vim.api.nvim_list_bufs()
				answer(nil, true)
				later(function()
					assert(#vim.api.nvim_list_bufs() <= count)
					check("cancelamento do caminho")
					local before = #inputs
					local templates = require("templates.picker").start("csharp")
					later(function()
						select(templates, "csharp/class")
						later(function()
							Snacks.picker.get()[1]:close()
							later(function()
								assert(#inputs == before, "Cancelar pasta abriu input")
								check("cancelamento da pasta não abre input nem cria arquivo")
								root_confirm()
							end)
						end)
					end)
				end)
			end)
		end)
	end)
end

local function create_files()
	creation("class", "Entities/Cliente", function()
		assert(vim.fn.readfile(project .. "/Entities/Cliente.cs")[3] == "public class Cliente")
		assert(
			vim.api.nvim_get_mode().mode == "i",
			"Cursor não entrou em inserção: " .. vim.inspect(vim.api.nvim_get_mode())
		)
		assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 5, 4 }))
		check("confirmação pelo Snacks.input e modo de inserção")
		creation("interface", "Contracts/ICliente", function()
			assert(vim.fn.readfile(project .. "/Contracts/ICliente.cs")[1] == "namespace MyApp.Contracts;")
			check("reabertura e namespace de outra pasta")
			creation("class", "Entities/TestEntity", function()
				local path = project .. "/Existing/Empty/Entities/TestEntity.cs"
				assert(vim.fn.readfile(path)[1] == "namespace MyApp.Existing.Empty.Entities;")
				assert(vim.fn.readfile(path)[3] == "public class TestEntity")
				assert(vim.fn.getcwd() == project, "Escolha da pasta alterou cwd original")
				check("pasta existente e subpastas no nome preservam destino e namespace")
				creation("class", "RootType", function()
					assert(vim.fn.readfile(project .. "/RootType.cs")[1] == "namespace MyApp;")
					check("opção raiz cria arquivo na raiz do projeto")
					path_cancel()
				end)
			end, "Existing/Empty/")
		end)
	end)
end

later(function()
	assert(vim.fn.exists(":Templates") == 2)
	assert(vim.fn.maparg("<leader>st", "n", false, true).callback)
	local completions = vim.fn.getcompletion("Templates ", "cmdline")
	for _, name in ipairs({ "all", "csharp", "go", "java", "typescript" }) do
		assert(vim.tbl_contains(completions, name), "Completion ausente: " .. name)
	end
	local mapping = vim.fn.maparg("<leader>st", "n", false, true)
	mapping.callback()
	later(function()
		local picker = assert(Snacks.picker.get()[1])
		assert(#picker:items() == 3)
		assert(picker.opts.title:find("csharp", 1, true))
		assert(picker.opts.preview == "file")
		check("comando, atalho, filtro por linguagem e preview")
		picker.input:set("class")
		picker:find()
		later(function()
			assert(#picker:items() == 1)
			picker:action("templates_toggle")
			later(function()
				local all = assert(Snacks.picker.get()[1])
				assert(all.opts.title:find("todas", 1, true))
				assert(all.input.filter.pattern == "class")
				all:action("templates_toggle")
				later(function()
					local current = assert(Snacks.picker.get()[1])
					assert(current.opts.title:find("csharp", 1, true))
					assert(current.input.filter.pattern == "class")
					current:close()
					check("alternância preserva linguagem capturada e busca")
					vim.bo.filetype = "java"
					vim.cmd("Templates java")
					later(function()
						local empty = assert(Snacks.picker.get()[1])
						assert(empty:count() == 0 and empty.opts.show_empty)
						empty:close()
						check("linguagem sem templates mostra lista vazia")
						vim.bo.filetype = ""
						vim.cmd("Templates")
						later(function()
							local unknown = assert(Snacks.picker.get()[1])
							assert(unknown.opts.title:find("todas", 1, true))
							unknown:close()
							assert(#inputs == 0, "Cancelar picker abriu input")
							check("buffer desconhecido e cancelamento do finder")
							vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
							vim.bo.filetype = "cs"
							vim.api.nvim_set_current_dir(project .. "/Existing")
							local nested = require("templates.picker").start()
							later(function()
								select(nested, "csharp/class")
								later(function()
									local directories = assert(Snacks.picker.get()[1])
									assert(directories.opts.cwd == project)
									local names = vim.tbl_map(function(entry) return entry.text end, directories:items())
									for _, name in ipairs({ ". (raiz)", "Existing/", "Existing/Empty/", ".Hidden/" }) do
										assert(vim.tbl_contains(names, name), "Pasta ausente: " .. name)
									end
									assert(not vim.tbl_contains(names, ".git/"))
									assert(not vim.tbl_contains(names, "MyApp.csproj"))
									directories:close()
									vim.api.nvim_set_current_dir(project)
									check("pastas vazias, ocultas e raiz detectada acima do cwd")
									create_files()
								end)
							end)
						end)
					end)
				end)
			end)
		end)
	end)
end, 20)
later(function()
	error("Timeout dos testes do finder")
end, 20000)
