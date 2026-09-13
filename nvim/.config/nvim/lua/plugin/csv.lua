-- CSV table rendering. Large files are presented through a read-only preview
-- so the original buffer is never truncated or modified.
vim.pack.add({
	"https://github.com/hat0uma/csvview.nvim",
})

local csvview = require("csvview")
local max_preview_rows = 200
local globally_enabled = false

csvview.setup({
	view = {
		display_mode = "border",
		sticky_header = { enabled = true },
	},
})

local function is_csv(bufnr)
	return vim.bo[bufnr].filetype == "csv" or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":e") == "csv"
end

local function preview_buffer(source)
	local cached = vim.b[source].csvview_preview_bufnr
	if cached and vim.api.nvim_buf_is_valid(cached) then
		return cached
	end

	local preview = vim.api.nvim_create_buf(false, true)
	local rows = vim.api.nvim_buf_get_lines(source, 0, max_preview_rows, false)
	local source_name = vim.api.nvim_buf_get_name(source)
	if source_name == "" then
		source_name = ("buffer-%d"):format(source)
	end
	vim.api.nvim_buf_set_name(preview, ("csv-preview://%s"):format(source_name))
	vim.api.nvim_buf_set_lines(preview, 0, -1, false, rows)
	vim.bo[preview].filetype = "csv"
	vim.bo[preview].modifiable = false
	vim.bo[preview].bufhidden = "wipe"
	vim.b[preview].csvview_preview_source = source
	vim.b[source].csvview_preview_bufnr = preview
	return preview
end

local function enable_csv_buffer(bufnr)
	if vim.b[bufnr].csvview_preview_source then
		csvview.enable(bufnr)
		return bufnr
	end

	if vim.api.nvim_buf_line_count(bufnr) > max_preview_rows then
		local preview = preview_buffer(bufnr)
		csvview.enable(preview)
		return preview
	end

	csvview.enable(bufnr)
	return bufnr
end

local function csv_buffers()
	local buffers = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and is_csv(bufnr) and not vim.b[bufnr].csvview_preview_source then
			table.insert(buffers, bufnr)
		end
	end
	return buffers
end

local function disable_all_csv_views()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and csvview.is_enabled(bufnr) then
			csvview.disable(bufnr)
		end
	end
end

local function toggle_csv_globally()
	if globally_enabled then
		local source = vim.b[vim.api.nvim_get_current_buf()].csvview_preview_source
		disable_all_csv_views()
		globally_enabled = false
		if source and vim.api.nvim_buf_is_valid(source) then
			vim.api.nvim_set_current_buf(source)
		end
		return
	end

	globally_enabled = true
	local current = vim.api.nvim_get_current_buf()
	local current_preview
	for _, bufnr in ipairs(csv_buffers()) do
		local rendered = enable_csv_buffer(bufnr)
		if bufnr == current then
			current_preview = rendered
		end
	end

	if current_preview and current_preview ~= current then
		vim.api.nvim_set_current_buf(current_preview)
		vim.notify(("CSV grande: exibindo as primeiras %d linhas em uma prévia somente-leitura."):format(max_preview_rows))
	end
end

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("csv-rendering", { clear = true }),
	pattern = "csv",
	callback = function(event)
		if globally_enabled and not vim.b[event.buf].csvview_preview_source then
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(event.buf) and not vim.b[event.buf].csvview_preview_source then
					local rendered = enable_csv_buffer(event.buf)
					if rendered ~= event.buf and vim.api.nvim_get_current_buf() == event.buf then
						vim.api.nvim_set_current_buf(rendered)
						vim.notify(("CSV grande: exibindo as primeiras %d linhas em uma prévia somente-leitura."):format(max_preview_rows))
					end
				end
			end)
		end
	end,
})

vim.keymap.set("n", "<leader>mc", toggle_csv_globally, { desc = "Toggle CSV table rendering globally" })
