local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

local function snippets()
	return {
		s(
			"tfn",
			fmt("function {}({}: {}) {{\n\t{}\n}}", {
				i(1, "name"),
				i(2, "value"),
				i(3, "string"),
				i(0),
			})
		),
		s(
			"taf",
			fmt("const {} = ({}: {}) => {{\n\t{}\n}}", {
				i(1, "name"),
				i(2, "value"),
				i(3, "string"),
				i(0),
			})
		),
		s(
			"int",
			fmt("interface {} {{\n\t{}: {}\n}}", {
				i(1, "Props"),
				i(2, "name"),
				i(3, "string"),
			})
		),
		s(
			"type",
			fmt("type {} = {{\n\t{}: {}\n}}", {
				i(1, "Props"),
				i(2, "name"),
				i(3, "string"),
			})
		),
		s(
			"imp",
			fmt([[import {{ {} }} from "{}"]], {
				i(1, "name"),
				i(2, "module"),
			})
		),
		s(
			"exp",
			fmt([[export {{ {} }}]], {
				i(1, "name"),
			})
		),
		s(
			"try",
			fmt("try {{\n\t{}\n}} catch (error) {{\n\t{}\n}}", {
				i(1),
				i(0),
			})
		),
		s(
			"clog",
			fmt([[console.log({})]], {
				i(1, "value"),
			})
		),
	}
end

ls.add_snippets("typescript", snippets())
ls.add_snippets("typescriptreact", snippets())
