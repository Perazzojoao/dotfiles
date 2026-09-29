local M = {}

local keywords = {}
for word in
	([[abstract as base bool break byte case catch char checked class const continue decimal
default delegate do double else enum event explicit extern false finally fixed float for foreach goto
if implicit in int interface internal is lock long namespace new null object operator out override
params private protected public readonly ref return sbyte sealed short sizeof stackalloc static string
struct switch this throw true try typeof uint ulong unchecked unsafe ushort using virtual void volatile while]]):gmatch(
		"%S+"
	)
do
	keywords[word] = true
end

local function identifier(value)
	local bare = value:gsub("^@", "")
	return bare:match("^[%a_][%w_]*$") and (value:sub(1, 1) == "@" or not keywords[bare])
end

function M.resolve(context)
	if not identifier(context.name) then
		return nil, { message = "Nome de tipo C# inválido: " .. context.name }
	end
	local directory = vim.fs.dirname(context.target)
	local project = vim.fs.find(function(name)
		return name:match("%.csproj$") ~= nil
	end, { path = directory, upward = true, type = "file", limit = 1 })[1]
	local root = project and vim.fs.dirname(project) or context.root or context.cwd
	local relative = vim.fs.relpath(root, directory)
	if not relative then
		if not context.root and not project then
			return nil, { root_required = true, message = "Selecione a pasta raiz do projeto C#." }
		end
		return nil, { message = "A pasta raiz deve conter o arquivo de destino." }
	end
	local namespace = vim.fs.basename(root)
	if relative ~= "" and relative ~= "." then
		namespace = namespace .. "." .. relative:gsub("/", ".")
	end
	for _, part in ipairs(vim.split(namespace, ".", { plain = true })) do
		if not identifier(part) then
			return nil, { message = "Pasta com nome inválido para namespace C#: " .. part }
		end
	end
	return { namespace = namespace }
end

return M
