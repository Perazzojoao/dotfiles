-- Run after normal startup: nvim --headless -i NONE -c 'luafile tests/tabout.lua'
local config = require("blink.cmp.config")
local handler = config.keymap["<Tab>"][1]
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
		end,
		accept = function()
			record("copilot")
		end,
	}
	check(
		"salto local do snippet antes do menu e Copilot",
		{ local_snippet = true, menu = true, copilot = true },
		{ "hide", "dismiss", "snippet" }
	)
	check(
		"menu antes de estado antigo de snippet e Copilot",
		{ menu = true, broad_snippet = true, copilot = true },
		{ "menu" }
	)
	check("menu antes de Copilot", { menu = true, copilot = true }, { "menu" })
	check("snippet antes de Copilot sem menu", { broad_snippet = true, copilot = true }, { "snippet" })
	check("Copilot antes de navegação por delimitadores", { copilot = true }, { "copilot" })
	check("fallback sem menu, snippet ou Copilot", {}, {})
	assert(config.keymap["<S-Tab>"][1] == "snippet_backward")
	assert(config.keymap["<S-Tab>"][2] == require("config.tabout").backward)
	cases = cases + 1
	print("PASS Shift-Tab mantém salto anterior do snippet")
	local early = vim.fn.maparg("<Tab>", "i", false, true).callback
	assert(early)
	package.loaded["blink.cmp"] = cmp
	require("config.tabout").forward = function()
		return record("tabout")
	end
	vim.snippet.active = function()
		return state.native_snippet
	end
	vim.snippet.jump = function()
		record("native_snippet")
	end
	state, calls = { copilot = true }, {}
	early()
	assert(vim.deep_equal(calls, { "copilot" }))
	cases = cases + 1
	print("PASS fallback de startup mantém Copilot antes de tabout")
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
