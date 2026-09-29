local M = {}

function M.list(language)
	local template = require("template")
	local languages = require("templates.languages")
	local items, seen = {}, {}
	for filetype, paths in pairs(template.get_temp_list()) do
		for _, path in ipairs(paths) do
			local relative = vim.fs.relpath(template.temp_dir, path)
			local group = relative and relative:match("^([^/]+)/")
			local config = group and languages.registry[group]
			local extension = config and config.filetypes[filetype]
			if extension and (not language or group == language) and not seen[path] then
				seen[path] = true
				items[#items + 1] = {
					text = relative:gsub("%.[^./]+$", ""),
					file = path,
					filetype = filetype,
					language = group,
					extension = extension,
				}
			end
		end
	end
	table.sort(items, function(a, b)
		return a.text < b.text
	end)
	return items
end

return M
