local function require_plugin(module)
  local ok, err = pcall(require, module)

  if ok then
    return
  end

  if vim and vim.notify then
    vim.notify(("Failed to load %s: %s"):format(module, err), vim.log.levels.ERROR)
  end
end

require_plugin("plugin.00-colorscheme")
require_plugin("plugin.01-snack")
require_plugin("plugin.syntax")
require_plugin("plugin.markdown")
require_plugin("plugin.pdfreader")
require_plugin("plugin.csv")
require_plugin("plugin.completion")
require_plugin("plugin.git")
require_plugin("plugin.editor")
require_plugin("plugin.lsp")
require_plugin("plugin.ui")
