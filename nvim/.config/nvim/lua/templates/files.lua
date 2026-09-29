local M = {}
local uv = vim.uv

local function failure(message)
	return nil, { message = message }
end

function M.path(value, cwd)
	local path = vim.fn.expand(value)
	if not vim.startswith(path, "/") then
		path = vim.fs.joinpath(cwd, path)
	end
	return vim.fs.normalize(path)
end

local function occupied(target)
	if uv.fs_lstat(target) then
		return "O destino já existe: " .. target
	end
	for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(buffer)
		if name ~= "" and vim.fs.normalize(name) == target then
			return "O destino já está aberto em um buffer: " .. target
		end
	end
end

local function ensure_directory(directory)
	local missing, created = {}, {}
	local function rollback()
		for index = #created, 1, -1 do
			uv.fs_rmdir(created[index]) -- Keep directories populated by another process.
		end
	end
	local ancestor = directory
	while true do
		local stat = uv.fs_stat(ancestor)
		if stat then
			if stat.type ~= "directory" then
				return nil, "O caminho não é uma pasta: " .. ancestor
			end
			break
		end
		missing[#missing + 1] = ancestor
		local parent = vim.fs.dirname(ancestor)
		if not parent or parent == ancestor then
			return nil, "Não foi possível localizar a pasta ancestral: " .. directory
		end
		ancestor = parent
	end
	for index = #missing, 1, -1 do
		local path = missing[index]
		local made, err = uv.fs_mkdir(path, 493)
		if made then
			created[#created + 1] = path
		else
			local stat = uv.fs_stat(path)
			if not stat or stat.type ~= "directory" then
				rollback()
				return nil, "Não foi possível criar a pasta " .. path .. ": " .. tostring(err)
			end
		end
	end
	return rollback
end

function M.prepare(item, value, options)
	if not value or vim.trim(value) == "" then
		return nil
	end
	if value:match("/$") then
		return failure("Informe o caminho incluindo o nome do arquivo.")
	end
	local target = M.path(value, options.cwd)
	local extension = vim.fn.fnamemodify(target, ":e")
	if extension == "" then
		target = target .. item.extension
	elseif "." .. extension ~= item.extension then
		return failure("Este template cria arquivos " .. item.extension .. ".")
	end
	local conflict = occupied(target)
	if conflict then
		return failure(conflict)
	end
	local context = {
		target = target,
		name = vim.fn.fnamemodify(target, ":t:r"),
		cwd = options.cwd,
		root = options.root and M.path(options.root, options.cwd) or nil,
	}
	if context.root then
		local stat = uv.fs_stat(context.root)
		if not stat or stat.type ~= "directory" then
			return failure("A pasta raiz selecionada não existe.")
		end
	end
	local variables, err = require("templates.languages").resolve(item.language, context)
	if not variables then
		return nil, err
	end
	context.variables = variables
	return context
end

function M.create(item, value, options)
	local context, err = M.prepare(item, value, options)
	if not context then
		return nil, err
	end
	local rollback, directory_err = ensure_directory(vim.fs.dirname(context.target))
	if not rollback then
		return failure(directory_err)
	end
	local ok, rendered = pcall(require("templates.render").render, item, context)
	if not ok then
		rollback()
		return failure("Não foi possível gerar o template: " .. tostring(rendered))
	end
	-- Rendering may prompt for custom variables. Recheck buffers afterwards;
	-- exclusive creation also catches files created by other processes meanwhile.
	local conflict = occupied(context.target)
	if conflict then
		rollback()
		return failure(conflict)
	end
	local fd, open_err = uv.fs_open(context.target, "wx", 420)
	if not fd then
		rollback()
		return failure("Não foi possível criar o arquivo: " .. tostring(open_err))
	end
	local created_stat = uv.fs_fstat(fd)
	local function cleanup()
		local current_stat = uv.fs_lstat(context.target)
		if
			created_stat
			and current_stat
			and created_stat.dev == current_stat.dev
			and created_stat.ino == current_stat.ino
		then
			uv.fs_unlink(context.target)
		end
		uv.fs_close(fd)
	end
	local content = table.concat(rendered.lines, "\n") .. "\n"
	local offset = 0
	while offset < #content do
		local written, write_err = uv.fs_write(fd, content:sub(offset + 1), offset)
		if not written or written == 0 then
			cleanup()
			rollback()
			return failure("Não foi possível escrever o arquivo: " .. tostring(write_err))
		end
		offset = offset + written
	end
	local closed, close_err = uv.fs_close(fd)
	if not closed then
		return failure(
			"Arquivo criado em " .. context.target .. ", mas não foi possível fechá-lo: " .. tostring(close_err)
		)
	end

	local opened, buffer = pcall(function()
		local bufnr = vim.fn.bufadd(context.target)
		vim.fn.bufload(bufnr)
		vim.bo[bufnr].buflisted = true
		vim.bo[bufnr].filetype = item.filetype
		local window = options.window
		if window and vim.api.nvim_win_is_valid(window) then
			vim.api.nvim_set_current_win(window)
		end
		vim.api.nvim_set_current_buf(bufnr)
		vim.api.nvim_win_set_cursor(0, rendered.cursor)
		local target_window = vim.api.nvim_get_current_win()
		local line = rendered.lines[rendered.cursor[1]] or ""
		local insert = rendered.cursor[2] >= #line and "startinsert!" or "startinsert"
		-- Let the prompt's pending InsertLeave finish before entering the file.
		vim.defer_fn(function()
			if vim.api.nvim_get_current_buf() == bufnr and vim.api.nvim_get_current_win() == target_window then
				vim.cmd(insert)
			end
		end, 10)
		return bufnr
	end)
	if not opened then
		return failure(
			"Arquivo criado em " .. context.target .. ", mas não foi possível abri-lo: " .. tostring(buffer)
		)
	end
	return { path = context.target, buffer = buffer }
end

return M
