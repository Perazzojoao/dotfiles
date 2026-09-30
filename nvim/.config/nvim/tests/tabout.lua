-- Run after normal startup: nvim --headless -i NONE -c 'luafile tests/tabout.lua'
local config = require("blink.cmp.config")
local handler = config.keymap["<Tab>"][1]
local escape_handler = config.keymap["<Esc>"][1]
local original_snippets = package.loaded["luasnip"]
local original_suggestion = package.loaded["copilot.suggestion"]
local original_blink = package.loaded["blink.cmp"]
local original_native_active, original_native_jump = vim.snippet.active, vim.snippet.jump
local original_forward = require("config.tabout").forward
local state, calls = {}, {}
local cases = 0
local function record(action)
	calls[#calls + 1] = action
	return true
end
local cmp = {
	hide = function()
		record("hide")
	end,
	is_menu_visible = function()
		return state.menu
	end,
	select_and_accept = function()
		return record("menu")
	end,
	snippet_active = function()
		return state.broad_snippet
	end,
	snippet_forward = function()
		return record("snippet")
	end,
}
local function check(name, flags, expected)
	state, calls = flags, {}
	handler(cmp)
	assert(vim.deep_equal(calls, expected), name .. ": " .. vim.inspect(calls))
	cases = cases + 1
	print("PASS " .. name)
end
local function run()
	package.loaded["luasnip"] = {
		locally_jumpable = function()
			return state.local_snippet
		end,
	}
	package.loaded["copilot.suggestion"] = {
		is_visible = function()
			return state.copilot
		end,
		dismiss = function()
			record("dismiss")
			state.copilot = false
		end,
		accept = function()
			record("copilot")
		end,
	}
	check(
		"menu antes do salto local do snippet e Copilot",
		{ local_snippet = true, menu = true, copilot = true },
		{ "menu" }
	)
	check(
		"Copilot antes do salto local do snippet com menu fechado",
		{ local_snippet = true, copilot = true },
		{ "copilot" }
	)
	check(
		"menu antes de estado antigo de snippet e Copilot",
		{ menu = true, broad_snippet = true, copilot = true },
		{ "menu" }
	)
	check("menu antes de Copilot", { menu = true, copilot = true }, { "menu" })
	check("Copilot antes de snippet ativo sem menu", { broad_snippet = true, copilot = true }, { "copilot" })
	check("salto local sem sugestão Copilot", { local_snippet = true }, { "hide", "snippet" })
	check("snippet ativo sem sugestão Copilot", { broad_snippet = true }, { "snippet" })
	state, calls = { local_snippet = true, copilot = true }, {}
	require("copilot.suggestion").dismiss()
	calls = {}
	handler(cmp)
	assert(vim.deep_equal(calls, { "hide", "snippet" }))
	cases = cases + 1
	print("PASS salto local após rejeitar sugestão Copilot")
	check("Copilot antes de navegação por delimitadores", { copilot = true }, { "copilot" })
	check("fallback sem menu, snippet ou Copilot", {}, {})
	for _, case in ipairs({
		{ name = "Esc dispensa Copilot", flags = { copilot = true }, expected = { "dismiss" }, consumed = true },
		{ name = "Esc sem sugestão segue fallback", flags = {}, expected = { "hide" } },
		{ name = "Esc com menu e sem Copilot segue fallback", flags = { menu = true }, expected = { "hide" } },
	}) do
		state, calls = case.flags, {}
		assert(escape_handler(cmp) == case.consumed)
		assert(vim.deep_equal(calls, case.expected), case.name .. ": " .. vim.inspect(calls))
		cases = cases + 1
		print("PASS " .. case.name)
	end
	assert(config.keymap["<Esc>"][2] == "fallback")
	assert(require("copilot.config").suggestion.keymap.dismiss == false)
	assert(config.keymap["<S-Tab>"][1] == "snippet_backward")
	assert(config.keymap["<S-Tab>"][2] == require("config.tabout").backward)
	cases = cases + 1
	print("PASS Shift-Tab mantém salto anterior do snippet")
	local early = vim.fn.maparg("<Tab>", "i", false, true).callback
	assert(early)
	package.loaded["blink.cmp"] = cmp
	local early_escape = vim.fn.maparg("<Esc>", "i", false, true).callback
	state, calls = { copilot = true }, {}
	assert(early_escape() == "")
	assert(vim.deep_equal(calls, { "dismiss" }))
	cases = cases + 1
	print("PASS Esc durante startup dispensa Copilot")
	state, calls = {}, {}
	assert(early_escape() == vim.api.nvim_replace_termcodes("<Esc>", true, true, true))
	assert(vim.deep_equal(calls, { "hide" }))
	cases = cases + 1
	print("PASS Esc durante startup mantém saída do Insert")
	require("config.tabout").forward = function()
		return record("tabout")
	end
	vim.snippet.active = function()
		return state.native_snippet
	end
	vim.snippet.jump = function()
		record("native_snippet")
	end
	state, calls = { menu = true, local_snippet = true, native_snippet = true, copilot = true }, {}
	early()
	assert(vim.deep_equal(calls, { "menu" }))
	cases = cases + 1
	print("PASS fallback de startup mantém menu antes dos snippets e Copilot")
	state, calls = { copilot = true, local_snippet = true, broad_snippet = true, native_snippet = true }, {}
	early()
	assert(vim.deep_equal(calls, { "copilot" }))
	cases = cases + 1
	print("PASS fallback de startup mantém Copilot antes dos snippets e tabout")
	state, calls = { native_snippet = true }, {}
	early()
	assert(vim.deep_equal(calls, { "native_snippet" }))
	cases = cases + 1
	print("PASS fallback de startup mantém snippet nativo")
	state, calls = {}, {}
	early()
	assert(vim.deep_equal(calls, { "tabout" }))
	cases = cases + 1
	print("PASS fallback de startup alcança tabout")
end
local ok, err = xpcall(run, debug.traceback)
package.loaded["luasnip"] = original_snippets
package.loaded["copilot.suggestion"] = original_suggestion
package.loaded["blink.cmp"] = original_blink
vim.snippet.active, vim.snippet.jump = original_native_active, original_native_jump
require("config.tabout").forward = original_forward
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
else
	print("TABOUT_PRIORITY_OK " .. cases .. " cases")
	vim.cmd("qa!")
end
