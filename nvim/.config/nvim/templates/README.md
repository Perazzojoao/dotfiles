# Templates de arquivos

`<leader>st` abre o finder do Snacks com os templates da linguagem do buffer atual.
Use `Alt-A` no finder para alternar entre essa linguagem e todas, mantendo a busca.
Em buffers sem linguagem reconhecida, o finder mostra todas as linguagens.

Também é possível executar `:Templates`, `:Templates all` ou
`:Templates csharp|java|go|typescript`. O comando oferece completion dos argumentos.
Uma linguagem sem modelos mostra uma lista vazia. Inicialmente estão disponíveis
`csharp/class`, `csharp/interface` e `csharp/enum`.

Selecione um modelo, escolha a pasta de destino em um segundo finder do Snacks,
informe o caminho do novo arquivo e confirme. A opção `. (raiz)` cria o arquivo
na raiz do projeto. As outras opções mostram as pastas existentes com seus
caminhos relativos à raiz, incluindo pastas vazias e ocultas; `.git` é excluída.

A raiz é detectada a partir do arquivo atual (ou da pasta de trabalho em um
buffer sem arquivo), usando o ancestral mais próximo com `.git`, `.csproj`,
`.sln`, `.slnx`, `package.json`, `go.mod`, `pom.xml` ou `build.gradle[.kts]`.
Sem um desses marcadores, usa-se a pasta de trabalho capturada ao abrir o finder.

Caminhos relativos usam a pasta selecionada; caminhos absolutos também são
aceitos. A conclusão de nomes no input usa a pasta selecionada sem alterar a
pasta de trabalho da janela original. As subpastas são verificadas e criadas
automaticamente antes da renderização do template. Se a geração falhar, as
pastas criadas nessa operação são removidas quando ainda estiverem vazias.
A extensão é acrescentada quando omitida; uma extensão incompatível é recusada.
Por exemplo, escolher `csharp/class`, selecionar `. (raiz)` e informar
`Entities/TestEntity` cria `<raiz>/Entities/TestEntity.cs`. Selecionando `src/`,
o mesmo nome cria `<raiz>/src/Entities/TestEntity.cs`. O cursor é posicionado
dentro da classe em modo de inserção.

Arquivos existentes, links e destinos já abertos em buffers são recusados,
inclusive buffers ainda não salvos. Cancelar o template, a pasta, o caminho ou a
escolha da raiz não cria arquivos. O conteúdo inicial é gravado antes da abertura do buffer;
edições posteriores usam a configuração de salvamento já existente.

## Namespace C#

A raiz é a pasta do `.csproj` ancestral mais próximo do destino. Se não houver
`.csproj`, usa-se a raiz detectada ao abrir o finder quando ela contém o destino.
A pasta escolhida para o arquivo não substitui essa raiz no namespace. Para destinos
externos sem projeto, um segundo input solicita uma pasta raiz existente que
contenha o arquivo.

O namespace usa o nome dessa raiz e as subpastas, sem consultar `RootNamespace`
do `.csproj`: `/MyApp/Entities/Cliente.cs` gera `namespace MyApp.Entities;`.
O nome do tipo usa o nome do arquivo sem extensão. Os nomes devem ser
identificadores C# ASCII válidos; palavras reservadas exigem o prefixo `@`.
Pastas com espaços, hífens ou segmentos vazios são recusadas.

## Organização e extensão

Os modelos ficam em `templates/<linguagem>/`, com subpastas opcionais. O picker
mostra o caminho relativo, como `csharp/class` ou `java/domain/class`, preservando
a identificação mesmo quando dois modelos têm o mesmo nome.

| Pasta | Filetype | Extensão |
| --- | --- | --- |
| `csharp` | `cs` | `.cs` |
| `java` | `java` | `.java` |
| `go` | `go` | `.go` |
| `typescript` | `typescript`, `typescriptreact` | `.ts`, `.tsx` |

Java, Go e TypeScript já estão registrados, mas não possuem modelos iniciais.
Adicione arquivos com a extensão da linguagem na pasta correspondente. Também
é aceito o formato `.tpl` do template.nvim, com `;; <filetype>` na primeira linha.
Os modelos de uma pasta só são aceitos quando seu filetype pertence à linguagem.

Use `{{_file_name_}}` para o nome sem extensão e um único `{{_cursor_}}` para a
posição de edição. As expressões nativas do template.nvim continuam disponíveis.
`{{_namespace_}}` é resolvida exclusivamente para C#.

O catálogo, o picker, a criação de arquivos e o adaptador de renderização ficam
em `lua/templates/`. Regras por linguagem ficam em `lua/templates/languages/` e
são registradas em `lua/templates/languages.lua`. Ao adicionar modelos Java/Go
que precisem de package, implemente ali o resolver de pasta e registre sua
expressão; não reutilize as regras de namespace C#.

O plugin é fixado na revisão `308f6f8f0bf98cb7c71855ffa8a3019a5642d1cd`.
O adaptador reutiliza seu motor interno porque a API pública de criação não
oferece renderização síncrona nem criação exclusiva. Antes de atualizar essa
revisão, valide o adaptador e os testes abaixo.

## Validação

Na raiz desta configuração, após instalar os plugins:

```sh
NVIM_LOG_FILE=/tmp/nvim-template-tests.log nvim --headless -n -u NONE -i NONE -c 'luafile tests/templates.lua'
XDG_DATA_HOME=/tmp/nvim-template-picker-data NVIM_LOG_FILE=/tmp/nvim-template-picker-tests.log nvim --headless -n -u NONE -i NONE -c 'luafile tests/templates_picker.lua'
```

O primeiro comando valida criação, namespace, isolamento e preservação de
arquivos/buffers. Com `TEMPLATES_TEST_DOTNET=1`, também compila os três modelos
gerados usando o SDK .NET instalado. O segundo usa o picker real do Snacks e
callbacks agendados para verificar filtros, alternância, seleção da pasta,
criação na raiz ou em subpastas, cancelamentos, confirmação e inputs.
