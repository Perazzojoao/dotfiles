-- Run with: nvim --headless -n -u NONE -i NONE -l tests/templates_command.lua
local config = vim.fn.getcwd()
vim.opt.runtimepath:prepend(config)
vim.opt.packpath:append(vim.fn.expand("~/.local/share/nvim/site"))

-- Load the already installed plugin when the configuration requests it, as
-- vim.pack.add({ load = true }) does during init, without package installation.
local package_add = vim.pack.add
vim.pack.add = function(_, options)
	assert(options and options.load == true, "template.nvim precisa carregar seus plugin/ arquivos durante startup")
	vim.cmd("packadd template.nvim")
end
require("plugin.templates")
vim.pack.add = package_add

local sandbox = vim.fn.tempname()
vim.fn.mkdir(sandbox, "p")
local existing = sandbox .. "/Existing.cs"
vim.fn.writefile({ "DO NOT LOSE EXISTING CONTENT" }, existing)

local ok, err = xpcall(function()
	assert(vim.fn.exists(":Templates") == 2, "comando seguro :Templates não foi registrado")
	assert(vim.g.load_template == true, "plugin nativo não foi carregado antes da remoção do comando")
	-- Startup sources plugin/ files again after init; the upstream guard must
	-- prevent that pass from restoring the destructive command.
	vim.cmd("runtime plugin/template.lua")
	assert(vim.api.nvim_get_commands({}).Template == nil, "startup recriou o comando nativo :Template")
	vim.api.nvim_set_current_dir(sandbox)
	local command_ok = pcall(vim.cmd, "Template Existing.cs csharp/class")
	vim.api.nvim_set_current_dir(config)
	assert(
		vim.deep_equal(vim.fn.readfile(existing), { "DO NOT LOSE EXISTING CONTENT" }),
		"arquivo existente foi alterado pelo comando nativo"
	)
	assert(not command_ok, ":Template executou apesar de ter sido removido")
	assert(
		vim.api.nvim_get_commands({}).Template == nil,
		"comando nativo perigoso :Template ainda está registrado"
	)
end, debug.traceback)

vim.fn.delete(sandbox, "rf")
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
else
	print("TEMPLATE_COMMAND_OK")
	vim.cmd("qa!")
end
