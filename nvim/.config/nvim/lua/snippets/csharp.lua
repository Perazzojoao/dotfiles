local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep

ls.add_snippets("cs", {
	s("prop", fmt("public {} {} {{ get; set; }}", {
		i(1, "string"),
		i(2, "Name"),
	})),
	s("propinit", fmt("public {} {} {{ get; init; }}", {
		i(1, "string"),
		i(2, "Name"),
	})),
	s("propget", fmt("public {} {} {{ get; }}", {
		i(1, "string"),
		i(2, "Name"),
	})),
	s("getset", fmt("private {} {};\npublic {} {}\n{{\n\tget => {};\n\tset => {} = value;\n}}", {
		i(1, "string"),
		i(2, "_name"),
		rep(1),
		i(3, "Name"),
		rep(2),
		rep(2),
	})),
	s("ctor", fmt("public {}({})\n{{\n\t{}\n}}", {
		i(1, "ClassName"),
		i(2),
		i(0),
	})),
	s("class", fmt("public class {}\n{{\n\t{}\n}}", {
		i(1, "ClassName"),
		i(0),
	})),
	s("record", fmt("public record {}({});", {
		i(1, "Name"),
		i(0),
	})),
	s("interface", fmt("public interface {}\n{{\n\t{}\n}}", {
		i(1, "IService"),
		i(0),
	})),
	s("method", fmt("public {} {}({})\n{{\n\t{}\n}}", {
		i(1, "void"),
		i(2, "MethodName"),
		i(3),
		i(0),
	})),
	s("async", fmt("public async Task<{}> {}({})\n{{\n\t{}\n}}", {
		i(1, "string"),
		i(2, "MethodAsync"),
		i(3),
		i(0),
	})),
	s("try", fmt("try\n{{\n\t{}\n}}\ncatch (Exception ex)\n{{\n\t{}\n}}", {
		i(1),
		i(0),
	})),
	s("foreach", fmt("foreach (var {} in {})\n{{\n\t{}\n}}", {
		i(1, "item"),
		i(2, "items"),
		i(0),
	})),
	s("logger", fmt("private readonly ILogger<{}> _logger;", {
		i(1, "ClassName"),
	})),
	s("mapget", fmt('app.MapGet("{}", ({}) =>\n{{\n\treturn {};\n}});', {
		i(1, "/route"),
		i(2),
		i(0, "Results.Ok()"),
	})),
})
