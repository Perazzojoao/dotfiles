vim.g.mapleader = " "
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.nu = true
vim.opt.timeout = true
vim.opt.timeoutlen = 2000
vim.opt.ttimeout = true
vim.opt.ttimeoutlen = 50

vim.g.netrw_banner = 0

vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.opt.wrap = true
vim.opt.smartindent = true
vim.opt.inccommand = "split"

vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.laststatus = 3

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = vim.fn.stdpath("data") .. "/undodir"
vim.opt.undofile = true

vim.opt.clipboard:append("unnamedplus")
vim.opt.isfname:append("@-@")
vim.opt.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50"
vim.opt.scrolloff = 8
vim.opt.mouse = "a"

vim.opt.colorcolumn = "0"
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true

vim.o.cmdheight = 0
