local command_sources = {}
local script = debug.getinfo(1, "S").source:sub(2)
local config_root = vim.fn.fnamemodify(script, ":p:h:h")
local function source(path)
	path = (path or ""):gsub("^@", "")
	for _, prefix in ipairs({
		vim.fn.stdpath("data") .. "/site/pack/core/opt/",
		vim.fn.stdpath("config") .. "/",
		config_root .. "/",
	}) do
		if path:sub(1, #prefix) == prefix then
			return (prefix:find("/pack/core/opt/", 1, true) and "plugins/" or "config/") .. path:sub(#prefix + 1)
		end
	end
	return path
end
local function caller()
	for depth = 3, 12 do
		local info = debug.getinfo(depth, "S")
		if not info then
			break
		end
		if info.source:sub(1, 1) == "@" and not info.source:find("plugin_audit.lua", 1, true) then
			return source(info.source)
		end
	end
end
local native_create = vim.api.nvim_create_user_command
vim.api.nvim_create_user_command = function(name, action, options)
	command_sources[name] = caller()
	return native_create(name, action, options)
end

local function commands(current)
	local result = {}
	for name, command in pairs(current) do
		local origin = command_sources[name]
		if not origin and command.script_id and command.script_id > 0 then
			local script = vim.fn.getscriptinfo({ sid = command.script_id })[1]
			origin = script and source(script.name)
		end
		result[name] = {
			source = origin,
			definition = command.definition:gsub("<Lua[^>]*>", "<Lua callback>"),
			nargs = command.nargs,
			description = command.desc,
		}
	end
	return result
end
local function maps(current)
	local result = {}
	for _, map in ipairs(current) do
		local info = map.callback and debug.getinfo(map.callback, "S")
		result[map.lhs] = {
			rhs = map.rhs,
			source = info and source(info.source),
			description = map.desc,
			expr = map.expr,
			noremap = map.noremap,
		}
	end
	return result
end

PluginAudit = {}
function PluginAudit.write(path)
	local snapshot = {
		plugins = {},
		commands = commands(vim.api.nvim_get_commands({ builtin = false })),
		mappings = {},
		buffers = {},
	}
	for _, plugin in ipairs(vim.pack.get()) do
		snapshot.plugins[#snapshot.plugins + 1] =
			{ name = plugin.spec.name, source = plugin.spec.src, active = plugin.active }
	end
	for _, mode in ipairs({ "n", "i", "s", "x", "c", "t", "o" }) do
		snapshot.mappings[mode] = maps(vim.api.nvim_get_keymap(mode))
	end
	local initial = vim.api.nvim_get_current_buf()
	for _, filetype in ipairs({ "cs", "java", "typescript", "typescriptreact", "html", "markdown", "lua" }) do
		local buffer = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_set_current_buf(buffer)
		vim.bo[buffer].filetype = filetype
		vim.api.nvim_exec_autocmds("InsertEnter", { buffer = buffer, modeline = false })
		local entry = { commands = commands(vim.api.nvim_buf_get_commands(buffer, { builtin = false })), mappings = {} }
		for _, mode in ipairs({ "n", "i", "s", "x", "c", "t", "o" }) do
			entry.mappings[mode] = maps(vim.api.nvim_buf_get_keymap(buffer, mode))
		end
		snapshot.buffers[filetype] = entry
	end
	vim.api.nvim_set_current_buf(initial)
	vim.fn.writefile({ vim.json.encode(snapshot) }, path)
	print("PLUGIN_AUDIT_OK " .. #snapshot.plugins .. " plugins, " .. vim.tbl_count(snapshot.commands) .. " commands")
end
