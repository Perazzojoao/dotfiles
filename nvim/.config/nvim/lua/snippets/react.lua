local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

local function react_snippets()
	return {
		s(
			"rfc",
			fmt("export function {}({}: {}) {{\n\treturn (\n\t\t{}\n\t)\n}}", {
				i(1, "Component"),
				i(2, "props"),
				i(3, "Props"),
				i(0, "<div />"),
			})
		),
		s(
			"rafc",
			fmt("export const {} = ({}: {}) => {{\n\treturn (\n\t\t{}\n\t)\n}}", {
				i(1, "Component"),
				i(2, "props"),
				i(3, "Props"),
				i(0, "<div />"),
			})
		),
		s(
			"props",
			fmt("type {}Props = {{\n\t{}: {}\n}}", {
				i(1, "Component"),
				i(2, "name"),
				i(3, "string"),
			})
		),
		s(
			"us",
			fmt([[const [{}, set{}] = useState<{}>({})]], {
				i(1, "value"),
				i(2, "Value"),
				i(3, "string"),
				i(0, '""'),
			})
		),
		s(
			"ue",
			fmt("useEffect(() => {{\n\t{}\n}}, [{}])", {
				i(1),
				i(0),
			})
		),
		s(
			"um",
			fmt("const {} = useMemo(() => {{\n\treturn {}\n}}, [{}])", {
				i(1, "value"),
				i(2, "computedValue"),
				i(0),
			})
		),
		s(
			"uc",
			fmt("const {} = useCallback(({}) => {{\n\t{}\n}}, [{}])", {
				i(1, "handleAction"),
				i(2),
				i(3),
				i(0),
			})
		),
		s(
			"frag",
			fmt("<>\n\t{}\n</>", {
				i(0),
			})
		),
	}
end

ls.add_snippets("typescriptreact", react_snippets())
ls.add_snippets("javascriptreact", react_snippets())
