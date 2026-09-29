-- Run with the full configuration: nvim --headless -i NONE -c 'luafile tests/completion_ranking.lua'
local ranking = require("config.completion_ranking")
local kinds = vim.lsp.protocol.CompletionItemKind
local buffer = vim.api.nvim_create_buf(false, true)
local cases = 0

local function context(filetype, line, column)
	vim.bo[buffer].filetype = filetype
	return { bufnr = buffer, line = line, cursor = { 1, column } }
end

local function check(name, ctx, items, expected, first_sort)
	local sorts = ranking.sorts_for_context(ctx)
	assert(sorts[1] == (first_sort or ranking.compare_groups), name .. ": sorter contextual não ativo")
	require("blink.cmp.fuzzy.sort").sort(items, sorts)
	local labels = vim.tbl_map(function(item)
		return item.label
	end, items)
	assert(vim.deep_equal(labels, expected), name .. ": " .. vim.inspect(labels))
	cases = cases + 1
	print("PASS " .. name)
end

local function run()
	local config = require("blink.cmp.config")
	assert(config.fuzzy.sorts == ranking.sorts)
	assert(config.fuzzy.implementation == "prefer_rust_with_warning")
	assert(config.sources.providers.lsp.transform_items == nil)

	local cs = context("cs", "test.", 5)
	check("variáveis, métodos próprios, métodos de Object e outros tipos ficam agrupados", cs, {
		{ label = "ToString", kind = kinds.Method, source_id = "lsp", score = 100 },
		{ label = "MeuMetodo", kind = kinds.Method, source_id = "lsp", score = 1 },
		{ label = "MinhaPropriedade", kind = kinds.Property, source_id = "lsp", score = 3 },
		{ label = "Classe", kind = kinds.Class, source_id = "lsp", score = 500 },
		{ label = "MeuCampo", kind = kinds.Field, source_id = "lsp", score = 2 },
		{ label = "OutroMetodo", kind = kinds.Method, source_id = "lsp", score = 5 },
		{ label = "MinhaVariavel", kind = kinds.Variable, source_id = "lsp", score = 8 },
		{ label = "GetType", kind = kinds.Method, source_id = "lsp", score = 200 },
		{ label = "Snippet", kind = kinds.Snippet, source_id = "snippets", score = 999 },
		{ label = "SnippetMetodo", kind = kinds.Method, source_id = "snippets", score = 1001 },
		{ label = "SnippetLsp", kind = kinds.Snippet, source_id = "lsp", score = 1000 },
		{ label = "Funcao", kind = kinds.Function, source_id = "lsp", score = 4 },
		{ label = "MinhaConstante", kind = kinds.Constant, source_id = "lsp", score = 1 },
		{ label = "TipoGenerico", kind = kinds.TypeParameter, source_id = "lsp", score = 1 },
	}, {
		"MinhaVariavel",
		"MinhaPropriedade",
		"MeuCampo",
		"MinhaConstante",
		"OutroMetodo",
		"Funcao",
		"MeuMetodo",
		"GetType",
		"ToString",
		"Classe",
		"TipoGenerico",
		"SnippetMetodo",
		"SnippetLsp",
		"Snippet",
	})

	check("sortText desempata dentro do mesmo grupo", cs, {
		{ label = "Depois", kind = kinds.Method, source_id = "lsp", score = 4, sortText = "0002" },
		{ label = "Antes", kind = kinds.Method, source_id = "lsp", score = 4, sortText = "0001" },
	}, { "Antes", "Depois" })

	check("acesso condicional C# também agrupa", context("cs", "test?.Me", 8), {
		{ label = "Metodo", kind = kinds.Method, source_id = "lsp", score = 20 },
		{ label = "Propriedade", kind = kinds.Property, source_id = "lsp", score = 1 },
	}, { "Propriedade", "Metodo" })

	check(
		"acesso a membro TypeScript deixa snippets depois de todos os outros itens",
		context("typescript", "teste?.me", 9),
		{
			{ label = "SnippetLsp", kind = kinds.Snippet, source_id = "lsp", score = 1000 },
			{ label = "Campo", kind = kinds.Field, source_id = "lsp", score = 5 },
			{ label = "SnippetFonte", kind = kinds.Method, source_id = "snippets", score = 2000 },
			{ label = "Metodo", kind = kinds.Method, source_id = "lsp", score = 10 },
			{ label = "Tipo", kind = kinds.TypeParameter, source_id = "lsp", score = 1 },
		},
		{ "Metodo", "Campo", "Tipo", "SnippetFonte", "SnippetLsp" },
		ranking.compare_snippets
	)

	check("método Lua com dois-pontos também deixa snippets por último", context("lua", "teste:me", 8), {
		{ label = "Snippet", kind = kinds.Snippet, source_id = "snippets", score = 100 },
		{ label = "Metodo", kind = kinds.Method, source_id = "lsp", score = 1 },
	}, { "Metodo", "Snippet" }, ranking.compare_snippets)

	assert(vim.deep_equal(ranking.sorts_for_context(context("cs", "teste", 5)), { "score", "sort_text" }))
	assert(vim.deep_equal(ranking.sorts_for_context(context("lua", "teste", 5)), { "score", "sort_text" }))
	assert(vim.deep_equal(ranking.sorts_for_context(context("markdown", "teste.", 6)), { "score", "sort_text" }))
	cases = cases + 1
	print("PASS demais contextos preservam a ordenação original")
end

local ok, err = xpcall(run, debug.traceback)
vim.api.nvim_buf_delete(buffer, { force = true })
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
else
	print("COMPLETION_RANKING_OK " .. cases .. " cases")
	vim.cmd("qa!")
end
