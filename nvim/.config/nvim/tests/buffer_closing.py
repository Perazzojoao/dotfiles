"""Exercise the close mappings with a real Snacks explorer and process exit."""
import pathlib
import subprocess
import tempfile

CONFIG = pathlib.Path(__file__).resolve().parents[1]
SETUP = r'''
vim.opt.runtimepath:prepend(CONFIG)
vim.opt.packpath:append(vim.fn.expand("~/.local/share/nvim/site"))
vim.cmd("packadd snacks.nvim")
vim.g.mapleader = " "
vim.o.lines, vim.o.columns = 40, 120
vim.o.hidden = true
require("snacks").setup({ explorer = { enabled = true }, picker = { enabled = true } })
require("config.keymaps")
local function close(key)
  local mapping = vim.fn.maparg(" " .. key, "n", false, true)
  assert(type(mapping.callback) == "function")
  mapping.callback()
end
local function edit(name)
  vim.cmd.edit(vim.fn.fnameescape(ROOT .. "/" .. name))
  return vim.api.nvim_get_current_buf()
end
local first = edit("first.txt")
local second = edit("second.txt")
local main = vim.api.nvim_get_current_win()
local picker = Snacks.explorer.open({ cwd = ROOT })
vim.defer_fn(function()
  local ok, err = xpcall(function()
    assert(picker.list.win:valid(), "explorer did not open")
    local sidebar = picker.list.win.win
    local width = vim.api.nvim_win_get_width(sidebar)
    vim.api.nvim_set_current_win(main)
    CASE
  end, debug.traceback)
  if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
  end
end, 300)
vim.wait(10000, function() return false end)
error("test timed out")
'''
CASES = {
    "q preserves sidebar and exits on last buffer": '''
      close("q")
      assert(vim.api.nvim_win_is_valid(main), "editing window was closed")
      assert(vim.api.nvim_win_get_buf(main) == first)
      assert(vim.api.nvim_win_get_width(sidebar) == width, "explorer resized")
      vim.api.nvim_create_autocmd("VimLeavePre", { callback = function()
        vim.fn.writefile({"exited"}, ROOT .. "/exit-marker")
      end })
      close("q")
      error("last-buffer close returned without exiting")
    ''',
    "w saves, preserves sidebar and exits on last buffer": '''
      vim.api.nvim_buf_set_lines(second, 0, -1, false, {"saved second"})
      close("w")
      assert(vim.fn.readfile(ROOT .. "/second.txt")[1] == "saved second")
      assert(vim.api.nvim_win_is_valid(main))
      assert(vim.api.nvim_win_get_buf(main) == first)
      assert(vim.api.nvim_win_get_width(sidebar) == width)
      vim.api.nvim_buf_set_lines(first, 0, -1, false, {"saved first"})
      vim.api.nvim_create_autocmd("VimLeavePre", { callback = function()
        assert(vim.fn.readfile(ROOT .. "/first.txt")[1] == "saved first")
        vim.fn.writefile({"exited"}, ROOT .. "/exit-marker")
      end })
      close("w")
      error("last-buffer close returned without exiting")
    ''',
    "q refuses unsaved changes": '''
      vim.api.nvim_buf_set_lines(second, 0, -1, false, {"unsaved"})
      close("q")
      assert(vim.api.nvim_buf_is_valid(second) and vim.bo[second].modified)
      assert(vim.api.nvim_win_get_buf(main) == second)
      assert(vim.api.nvim_win_get_width(sidebar) == width)
      vim.fn.writefile({"passed"}, ROOT .. "/exit-marker")
      vim.cmd("qall!")
    ''',
    "last modified buffer prevents exit": '''
      close("q")
      vim.api.nvim_buf_set_lines(first, 0, -1, false, {"unsaved last"})
      local ok = pcall(close, "q")
      assert(not ok, "qall should refuse unsaved changes")
      assert(vim.api.nvim_buf_is_valid(first) and vim.bo[first].modified)
      assert(vim.api.nvim_win_is_valid(main))
      assert(vim.api.nvim_win_get_width(sidebar) == width)
      vim.fn.writefile({"passed"}, ROOT .. "/exit-marker")
      vim.cmd("qall!")
    ''',
    "unloaded listed file remains available": '''
      vim.api.nvim_buf_delete(first, { unload = true })
      assert(vim.bo[first].buflisted and not vim.api.nvim_buf_is_loaded(first))
      close("q")
      assert(vim.api.nvim_win_is_valid(main))
      assert(vim.api.nvim_win_get_buf(main) == first)
      assert(vim.api.nvim_win_get_width(sidebar) == width)
      vim.fn.writefile({"passed"}, ROOT .. "/exit-marker")
      vim.cmd("qall!")
    ''',
}
for name, case in CASES.items():
    with tempfile.TemporaryDirectory(prefix="nvim-buffer-close-") as directory:
        root = pathlib.Path(directory)
        for file in ("first.txt", "second.txt"):
            (root / file).write_text("original\n")
        script = root / "test.lua"
        # Lua long strings avoid shell interpolation and preserve path characters.
        script.write_text(f'local CONFIG = [[{CONFIG}]]\nlocal ROOT = [[{root}]]\n' + SETUP.replace("CASE", case))
        result = subprocess.run(["nvim", "--headless", "-n", "-u", "NONE", "-i", "NONE", "-l", str(script)], capture_output=True, text=True, timeout=20)
        assert result.returncode == 0, f"{name}\n{result.stdout}\n{result.stderr}"
        assert (root / "exit-marker").exists(), f"{name}: exit not verified"
        print("PASS", name)
print(f"BUFFER_CLOSING_OK {len(CASES)} cases")
