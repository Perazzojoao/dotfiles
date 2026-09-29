-- The renderer adapter is verified against this revision of template.nvim.
vim.pack.add({
	{ src = "https://github.com/nvimdev/template.nvim", version = "308f6f8f0bf98cb7c71855ffa8a3019a5642d1cd" },
})

require("template").setup({ temp_dir = vim.fn.stdpath("config") .. "/templates" })
require("templates.render").setup()

vim.api.nvim_create_user_command("Templates", function(command)
	require("templates.picker").start(command.args ~= "" and command.args or nil)
end, {
	nargs = "?",
	complete = function(lead)
		local arguments = require("templates.languages").names()
		table.insert(arguments, "all")
		return vim.tbl_filter(function(argument)
			return vim.startswith(argument, lead)
		end, arguments)
	end,
})

vim.keymap.set("n", "<leader>st", function()
	require("templates.picker").start()
end, { desc = "[S]earch [T]emplates" })
