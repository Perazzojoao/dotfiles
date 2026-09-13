-- Read PDF documents directly in Neovim. Opening a .pdf with :edit activates
-- pdfreader.nvim automatically; in terminals without Kitty/Ghostty graphics it
-- falls back to its text view.
vim.pack.add({
	"https://github.com/r-pletnev/pdfreader.nvim",
})

local has_poppler = vim.fn.executable("pdfinfo") == 1 and vim.fn.executable("pdftotext") == 1

if not has_poppler then
	vim.notify("PDFReader desativado: instale poppler-utils para abrir arquivos PDF.", vim.log.levels.WARN)
	return
end

local pdfreader_utils = require("pdfreader.utils")
local has_magick = vim.fn.executable("magick") == 1

if not has_magick then
	-- pdfreader.nvim creates a PNG cover even in text mode. Avoid invoking a
	-- missing ImageMagick binary and keep PDF reading available through Poppler.
	pdfreader_utils.convert_pdf_to_png = function()
		return nil
	end
	-- The plugin validates ImageMagick on every PDF buffer even after switching
	-- to text mode. Poppler was checked above and is sufficient for this mode.
	require("pdfreader.validation").check_depencencies = function()
		return true
	end
	vim.notify("PDFReader: ImageMagick ausente; usando visualização em texto.", vim.log.levels.WARN)
end

require("pdfreader").setup({
	mode = has_magick and pdfreader_utils.VIEW_MODES.normal or pdfreader_utils.VIEW_MODES.text,
})
