-- Run with: nvim --headless -u NONE -i NONE -c 'luafile tests/templates.lua'
local config = vim.fn.getcwd()
vim.opt.runtimepath:prepend(config)
vim.cmd("packadd template.nvim")
vim.o.hidden = true

local template = require("template")
template.setup({ temp_dir = config .. "/templates" })
require("templates.render").setup()
local catalog = require("templates.catalog")
local files = require("templates.files")
local sandbox = vim.fn.tempname()
local project = sandbox .. "/MyApp"
vim.fn.mkdir(project, "p")
vim.fn.writefile({
	'<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>',
}, project .. "/MyApp.csproj")
local options = { cwd = project }
local passed = 0

local function same(actual, expected)
	assert(vim.deep_equal(actual, expected), vim.inspect({ actual = actual, expected = expected }))
end

local function test(name, callback)
	callback()
	passed = passed + 1
	print("PASS " .. name)
end

local function fixture(path, lines)
	local target = sandbox .. "/" .. path
	vim.fn.mkdir(vim.fs.dirname(target), "p")
	vim.fn.writefile(lines, target)
	return target
end

local function item(name)
	for _, entry in ipairs(catalog.list("csharp")) do
		if entry.text == "csharp/" .. name then
			return entry
		end
	end
	error("Template ausente: " .. name)
end

local function rejected(value, needle, entry, opts)
	local result, err = files.create(entry or item("class"), value, opts or options)
	assert(not result and err, "Criação deveria ter sido recusada: " .. tostring(value))
	assert(err.message:find(needle, 1, true), err.message)
	return err
end

local function run()
	test("catálogo inicial e linguagens sem modelos", function()
		local ids = vim.tbl_map(function(entry)
			return entry.text
		end, catalog.list())
		same(ids, { "csharp/class", "csharp/enum", "csharp/interface" })
		same(catalog.list("java"), {})
	end)

	test("classe, interface e enum compiláveis com nome e namespace do destino", function()
		for _, kind in ipairs({ "class", "interface", "enum" }) do
			local name = ({ class = "Cliente", interface = "ICliente", enum = "Status" })[kind]
			local created, err = files.create(item(kind), "Entities/" .. name, options)
			assert(created, vim.inspect(err))
			same(vim.fn.readfile(created.path), {
				"namespace MyApp.Entities;",
				"",
				"public " .. kind .. " " .. name,
				"{",
				"    ",
				"}",
			})
			-- Normal mode clamps the column until the deferred startinsert!.
			same(vim.api.nvim_win_get_cursor(0), { 5, 3 })
			same(vim.bo[created.buffer].filetype, "cs")
			assert(not vim.bo[created.buffer].modified)
		end
	end)

	test("projeto ancestral mais próximo, ignorando RootNamespace", function()
		fixture(
			"MyApp/Nested/Module.csproj",
			{ "<Project><PropertyGroup><RootNamespace>Ignored</RootNamespace></PropertyGroup></Project>" }
		)
		local prepared = assert(files.prepare(item("class"), "Nested/Domain/Produto.cs", options))
		same(prepared.variables.namespace, "Nested.Domain")
		local root_type = assert(files.prepare(item("class"), "RootType.cs", options))
		same(root_type.variables.namespace, "MyApp")
	end)

	test("raiz por cwd ou escolha explícita fora dele", function()
		local outside = sandbox .. "/OtherApp"
		vim.fn.mkdir(outside, "p")
		local value = outside .. "/Models/Outro"
		local prepared, err = files.prepare(item("class"), value, options)
		assert(not prepared and err.root_required)
		assert(not vim.uv.fs_stat(outside .. "/Models"))
		prepared = assert(files.prepare(item("class"), value, { cwd = outside }))
		same(prepared.variables.namespace, "OtherApp.Models")
		prepared = assert(files.prepare(item("class"), value, { cwd = project, root = outside }))
		same(prepared.variables.namespace, "OtherApp.Models")
		rejected(value, "deve conter", nil, { cwd = project, root = project })
		rejected(value, "não existe", nil, { cwd = project, root = outside .. "/Missing" })
	end)

	test("cwd capturado, caminhos absolutos, subpastas e extensão", function()
		vim.api.nvim_set_current_dir(sandbox)
		local created = assert(files.create(item("class"), "Deep/Domain/Absoluto.cs", options))
		same(created.path, project .. "/Deep/Domain/Absoluto.cs")
		local absolute = assert(files.create(item("class"), project .. "/Entities/Outra", options))
		same(absolute.path, project .. "/Entities/Outra.cs")
		rejected("Invalido.java", "cria arquivos .cs")
		rejected("Pasta/", "incluindo o nome")
	end)

	test("pastas aninhadas existem antes da renderização", function()
		local entry = {
			file = fixture(
				"Directory.ts",
				{ "// parent: {{_lua:vim.fn.isdirectory(vim.fs.dirname(vim.api.nvim_buf_get_name(0)))_}}" }
			),
			filetype = "typescript",
			language = "typescript",
			extension = ".ts",
		}
		local directory = sandbox .. "/NewApp/Domain/Models"
		assert(not vim.uv.fs_stat(directory))
		local result, err = files.create(entry, directory .. "/Cliente", options)
		assert(result, vim.inspect(err))
		same(vim.fn.readfile(result.path), { "// parent: 1" })
		same(vim.uv.fs_stat(directory).type, "directory")
	end)

	test("arquivo no caminho das pastas é preservado", function()
		local blocked = fixture("MyApp/Blocked", { "preservar" })
		rejected("Blocked/Domain/Cliente", "não é uma pasta")
		same(vim.fn.readfile(blocked), { "preservar" })
		assert(not vim.uv.fs_stat(blocked .. "/Domain"))
	end)

	test("identificadores inválidos não criam diretórios nem arquivos", function()
		for _, value in ipairs({ "Bad Folder/Teste", "Bad-Name/Teste", "My..App/Teste", "Bad/123Teste", "Bad/class" }) do
			rejected(value, "inválido")
			assert(not vim.uv.fs_stat(files.path(value .. ".cs", project)))
		end
		assert(not vim.uv.fs_stat(project .. "/Bad"))
		local prepared = assert(files.prepare(item("class"), "@namespace/@class.cs", options))
		same(prepared.variables.namespace, "MyApp.@namespace")
	end)

	test("cancelamento mantém arquivos e buffers", function()
		local before = #vim.api.nvim_list_bufs()
		same({ files.create(item("class"), nil, options) }, {})
		same({ files.create(item("class"), "  ", options) }, {})
		same(#vim.api.nvim_list_bufs(), before)
	end)

	test("arquivo existente e link quebrado não são sobrescritos", function()
		local existing = fixture("MyApp/Preservado.cs", { "conteúdo anterior" })
		rejected(existing, "já existe")
		same(vim.fn.readfile(existing), { "conteúdo anterior" })
		assert(vim.uv.fs_symlink(project .. "/Missing.cs", project .. "/Link.cs"))
		rejected("Link.cs", "já existe")
		same(vim.uv.fs_lstat(project .. "/Link.cs").type, "link")
		vim.fn.delete(existing)
		vim.fn.delete(project .. "/Link.cs")
	end)

	test("buffer de destino não salvo e buffer de origem permanecem intactos", function()
		local destination = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(destination, project .. "/Unsaved.cs")
		vim.api.nvim_buf_set_lines(destination, 0, -1, false, { "não sobrescrever" })
		rejected("Unsaved", "aberto em um buffer")
		assert(not vim.uv.fs_stat(project .. "/Unsaved.cs"))
		same(vim.api.nvim_buf_get_lines(destination, 0, -1, false), { "não sobrescrever" })
		assert(vim.bo[destination].modified)
		vim.api.nvim_set_current_buf(destination)
		assert(files.create(item("class"), "FromOtherBuffer", options))
		same(vim.api.nvim_buf_get_lines(destination, 0, -1, false), { "não sobrescrever" })
		assert(vim.bo[destination].modified)
	end)

	test("erro de renderização limpa staging e não cria destino", function()
		local bad = {
			file = fixture("Bad.cs", { "{{_cursor_}}{{_cursor_}}" }),
			filetype = "cs",
			language = "csharp",
			extension = ".cs",
		}
		local before = #vim.api.nvim_list_bufs()
		rejected("Failed/NaoCriar", "marcador de cursor", bad)
		same(#vim.api.nvim_list_bufs(), before)
		assert(not vim.uv.fs_stat(project .. "/Failed"))
	end)

	test("arquivo criado durante renderização é preservado", function()
		local path = project .. "/Concurrent.cs"
		template.register("{{_race_}}", function()
			vim.fn.writefile({ "criado por outro processo" }, path)
			return "conteúdo do template"
		end)
		local concurrent =
			{ file = fixture("Race.cs", { "{{_race_}}" }), filetype = "cs", language = "csharp", extension = ".cs" }
		rejected(path, "já existe", concurrent)
		same(vim.fn.readfile(path), { "criado por outro processo" })
		vim.fn.delete(path)
	end)

	test("criação exclusiva protege contra concorrência após a validação", function()
		local target = project .. "/Raced.cs"
		local native_open = vim.uv.fs_open
		vim.uv.fs_open = function(path, flags, mode)
			if path == target and flags == "wx" then
				vim.fn.writefile({ "outra criação" }, target)
			end
			return native_open(path, flags, mode)
		end
		local ok, err = pcall(rejected, target, "Não foi possível criar o arquivo")
		vim.uv.fs_open = native_open
		assert(ok, err)
		same(vim.fn.readfile(target), { "outra criação" })
		vim.fn.delete(target)
	end)

	test("falha de escrita limpa apenas o arquivo recém-criado", function()
		local native_write = vim.uv.fs_write
		vim.uv.fs_write = function()
			return nil, "falha simulada"
		end
		local ok, err = pcall(rejected, "WriteFailed", "falha simulada")
		vim.uv.fs_write = native_write
		assert(ok, err)
		assert(not vim.uv.fs_stat(project .. "/WriteFailed.cs"))
	end)

	test("valores literais com porcentagem e staging excluído do autosave", function()
		local autocmd = vim.api.nvim_create_autocmd("BufLeave", {
			callback = function(event)
				if vim.bo[event.buf].buftype == "nofile" then
					assert(not vim.bo[event.buf].modifiable, "Staging elegível para autosave")
				end
			end,
		})
		local literal = {
			file = fixture(
				"Literal.ts",
				{ '// {{_file_name_}}: {{_lua:"100%"_}} {{_lua:tostring(vim.bo.modifiable)_}}' }
			),
			filetype = "typescript",
			language = "typescript",
			extension = ".ts",
		}
		local result, err = files.create(literal, sandbox .. "/Web/Rate%", options)
		vim.api.nvim_del_autocmd(autocmd)
		assert(result, vim.inspect(err))
		same(vim.fn.readfile(result.path), { "// Rate%: 100% false" })
	end)

	test("extensão e linguagem isoladas com nomes iguais e modelos aninhados", function()
		local old_directory = template.temp_dir
		fixture("Catalog/java/domain/class.java", { "public class {{_file_name_}} { {{_cursor_}} }" })
		fixture("Catalog/csharp/class.cs", { "namespace {{_namespace_}};" })
		fixture("Catalog/java/wrong.cs", { "não deve aparecer" })
		fixture("Catalog/go/class.go", { "package example" })
		fixture("Catalog/typescript/class.ts", { "export class {{_file_name_}} {}" })
		fixture(
			"Catalog/typescript/component.tpl",
			{ ";; typescriptreact", "export const {{_file_name_}} = () => <div />;" }
		)
		template.temp_dir = sandbox .. "/Catalog"
		local entries = catalog.list()
		same(
			vim.tbl_map(function(entry)
				return entry.text
			end, entries),
			{
				"csharp/class",
				"go/class",
				"java/domain/class",
				"typescript/class",
				"typescript/component",
			}
		)
		local java = catalog.list("java")[1]
		local created = assert(files.create(java, sandbox .. "/JavaApp/Produto", options))
		same(vim.fn.readfile(created.path), { "public class Produto {  }" })
		same(vim.bo[created.buffer].filetype, "java")
		local tsx = catalog.list("typescript")[2]
		local component = assert(files.create(tsx, sandbox .. "/Web/Component", options))
		same(component.path, sandbox .. "/Web/Component.tsx")
		same(vim.fn.readfile(component.path), { "export const Component = () => <div />;" })
		template.temp_dir = old_directory
	end)

	if vim.env.TEMPLATES_TEST_DOTNET == "1" then
		test("dotnet build dos modelos C# gerados", function()
			vim.fn.delete(project .. "/Nested", "rf")
			fixture("NuGet.Config", { "<configuration><packageSources><clear /></packageSources></configuration>" })
			local result = vim.system({
				"dotnet",
				"build",
				project .. "/MyApp.csproj",
				"--nologo",
				"--verbosity",
				"quiet",
				"--disable-build-servers",
			}, {
				text = true,
				timeout = 60000,
				env = {
					DOTNET_CLI_HOME = sandbox .. "/DotnetHome",
					DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1",
					DOTNET_CLI_TELEMETRY_OPTOUT = "1",
				},
			}):wait()
			assert(result.code == 0, (result.stdout or "") .. (result.stderr or ""))
		end)
	end
end

local ok, err = xpcall(run, debug.traceback)
for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
	if vim.startswith(vim.api.nvim_buf_get_name(buffer), sandbox .. "/") then
		vim.api.nvim_buf_delete(buffer, { force = true })
	end
end
vim.fn.delete(sandbox, "rf")
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
else
	print("TEMPLATES_OK " .. passed .. " cases")
	vim.cmd("qa!")
end
