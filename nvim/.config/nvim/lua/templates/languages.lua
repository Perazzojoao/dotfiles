local M = {}

M.registry = {
	csharp = { filetypes = { cs = ".cs" }, resolve = require("templates.languages.csharp").resolve },
	java = { filetypes = { java = ".java" } },
	go = { filetypes = { go = ".go" } },
	typescript = { filetypes = { typescript = ".ts", typescriptreact = ".tsx" } },
}

function M.for_filetype(filetype)
	for name, language in pairs(M.registry) do
		if language.filetypes[filetype] then
			return name
		end
	end
end

function M.names()
	local names = vim.tbl_keys(M.registry)
	table.sort(names)
	return names
end

function M.resolve(language, context)
	local resolver = M.registry[language].resolve
	if resolver then
		return resolver(context)
	end
	return {}
end

return M
