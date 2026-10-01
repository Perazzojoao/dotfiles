# Pendências do code review das customizações do Neovim

Revisão de 2026-09-30. Este documento registra os achados ainda pendentes;
a numeração corresponde ao relatório original. Os achados 1–3 foram tratados
separadamente: comando `:Template` inseguro, salto global antigo do LuaSnip e
perda do salto do tabout quando a próxima tecla chega antes do callback.

Todos os achados 4–12 abaixo são **P2**: comportamentos incorretos reproduzidos
que merecem correção. As localizações indicam o código revisado; os números de
linha podem mudar. Nenhuma dessas correções está incluída nesta etapa.

## 4. Autoclose altera atributos, strings e comentários

- **Código:** [lua/plugin/syntax.lua](../lua/plugin/syntax.lua),
  `get_void_tag_before_cursor` e `setup_autotag_keymaps` (linhas 131–148).
- **Causa:** a regex identifica uma tag sem verificar o contexto sintático.
- **Reprodução:** digitar `>` após `<img alt="a` insere ` />` dentro do atributo.
  Em TSX, `const example = "<img` também recebe essa transformação; o mesmo
  acontece com `<!-- <img`.
- **Impacto:** altera o conteúdo digitado em locais que não representam o
  fechamento de uma tag.
- **Correção proposta:** verificar o nó Treesitter e a posição fora de
  aspas/comentários antes de converter `>` em ` />`.
- **Critério de aceite:** atributos, strings e comentários recebem somente
  `>`; tags reais continuam com o fechamento esperado.

## 5. `:NewNotebook` cria metadados incompatíveis com nbformat

- **Código:** [lua/plugin/notebook.lua](../lua/plugin/notebook.lua),
  `default_notebook.cells` (linha 238).
- **Causa:** `metadata = {}` é serializado como `[]`, mas metadados de células
  devem ser objetos JSON.
- **Reprodução:** criar um notebook com `:NewNotebook` e lê-lo com
  `nbformat.read(path, as_version=4)`; o ambiente instalado retorna
  `TypeError: pop expected at most 1 argument, got 2`.
- **Impacto:** Jupytext não consegue converter o notebook gerado para Markdown.
- **Correção proposta:** usar `vim.empty_dict()` e adicionar um identificador
  de célula adequado ao formato declarado, `nbformat_minor = 5`.
- **Critério de aceite:** o notebook criado passa em `nbformat.validate` e
  abre/converte com o Jupytext instalado sem reparos de formato.

## 6. Importação automática do Molten usa o buffer errado

- **Código:** [lua/plugin/notebook.lua](../lua/plugin/notebook.lua),
  `import_notebook_outputs` (linhas 170–190).
- **Causa:** os comandos agendados usam o buffer atual, enquanto a flag de
  importação é marcada antecipadamente em `event.buf`.
- **Reprodução:** abrir `A.ipynb` e trocar para `B.txt` antes do callback;
  `MoltenInit` e `MoltenImportOutput` executam em B e A permanece marcado como
  importado. A reprodução instrumentou os comandos; o Molten instalado usa
  `self.nvim.current.buffer`.
- **Impacto:** inicialização/importação no arquivo errado e ausência de nova
  tentativa no notebook de origem.
- **Correção proposta:** executar no contexto de `event.buf`, explicitar o
  arquivo quando necessário e marcar a importação somente após sucesso.
- **Critério de aceite:** trocar de buffer durante a espera não muda o alvo;
  uma falha permite nova tentativa e não marca importação concluída.

## 7. Cache da prévia de CSV apresenta conteúdo antigo

- **Código:** [lua/plugin/csv.lua](../lua/plugin/csv.lua), `preview_buffer`
  (linhas 22–26).
- **Causa:** uma prévia válida é reutilizada sem verificar mudanças na origem.
- **Reprodução:** ativar CSV a partir de outro buffer, desligar, editar a
  origem e ativar novamente nela. A origem contém `CHANGED,ROW`, enquanto a
  prévia ainda mostra `1,2`.
- **Impacto:** a visualização apresenta dados desatualizados.
- **Correção proposta:** atualizar a prévia conforme o `changedtick` da origem
  ou invalidar o cache ao desligar.
- **Critério de aceite:** cada ativação mostra as primeiras 200 linhas atuais,
  sem modificar ou truncar o buffer de origem.

## 8. Desligamento global do CSV não restaura outras janelas

- **Código:** [lua/plugin/csv.lua](../lua/plugin/csv.lua),
  `toggle_csv_globally` (linhas 78–85).
- **Causa:** o retorno ao buffer original considera somente a janela atual.
- **Reprodução:** exibir uma prévia de um CSV de 201 linhas na janela A, abrir
  B e desligar com `<leader>mc` em B. A continua com uma prévia não modificável
  contendo somente 200 linhas.
- **Impacto:** o desligamento global deixa parte das janelas na visualização
  parcial e sem edição.
- **Correção proposta:** restaurar a origem em todas as janelas e abas que
  exibem buffers com `csvview_preview_source`.
- **Critério de aceite:** todas as janelas retornam à origem ao desligar,
  inclusive em outras abas, preservando seus arquivos e conteúdos.

## 9. Callback pendente reativa CSV depois do desligamento

- **Código:** [lua/plugin/csv.lua](../lua/plugin/csv.lua), autocmd `FileType`
  (linhas 105–118).
- **Causa:** `globally_enabled` é verificado antes do agendamento, mas não
  dentro do callback.
- **Reprodução:** ativar, disparar `FileType csv`, desligar antes de executar
  os callbacks. A visualização passa de desabilitada a habilitada novamente.
- **Impacto:** a ação de desligar é desfeita por uma execução pendente.
- **Correção proposta:** revalidar o estado dentro do callback e invalidar
  callbacks de ativações anteriores quando necessário.
- **Critério de aceite:** desligar mantém todas as visualizações desabilitadas
  mesmo após callbacks pendentes; desligar/ligar não aplica trabalho obsoleto.

## 10. img-clip usa caminho de outro usuário e encoder ausente

- **Código:** [lua/plugin/editor.lua](../lua/plugin/editor.lua), setup de
  `img-clip` (linhas 149–156).
- **Causa:** caminho fixo `/home/titus/github/website/static/images/<ano>/`,
  comando `/usr/bin/cwebp` e URLs Markdown vinculadas a esse site.
- **Reprodução:** nesta máquina, o destino e o executável estão ausentes;
  o processamento de uma imagem em arquivo temporário retorna código 127.
- **Impacto:** a colagem/processamento falha, e os links presumem uma estrutura
  que não corresponde ao projeto atual.
- **Correção proposta:** definir destino adequado ao projeto e validar ou
  configurar um encoder disponível.
- **Critério de aceite:** colar uma imagem grava no destino esperado e gera
  um link resolvível; dependência ausente recebe tratamento claro.

## 11. Snippets JSX geram sintaxe TypeScript em JavaScript

- **Código:** [lua/snippets/react.lua](../lua/snippets/react.lua),
  `react_snippets` e registro em `javascriptreact` (linha 77).
- **Causa:** JSX e TSX compartilham snippets contendo anotações de tipos,
  aliases e parâmetros genéricos.
- **Reprodução:** expandir `rfc`, `rafc` ou `props` em `javascriptreact` gera,
  por exemplo, `props: Props` ou `type ComponentProps`; o parser JavaScript
  instalado sinaliza erros. `us` também inclui `useState<string>(...)`.
- **Impacto:** snippets inserem código inadequado ao tipo do arquivo.
- **Correção proposta:** criar variantes JSX sem tipos ou restringir os
  snippets tipados a `typescriptreact`.
- **Critério de aceite:** expansões JSX são JavaScript válido e TSX mantém
  seus tipos; testar também a semântica do snippet de `useState`.

## 12. Desconectar um LSP remove highlights dos demais

- **Código:** [lua/plugin/lsp.lua](../lua/plugin/lsp.lua), autocmds de
  document highlight e `LspDetach` (linhas 371–386).
- **Causa:** cada attach registra novos callbacks, e qualquer detach remove
  todos os callbacks de highlight do buffer.
- **Reprodução:** com dois clientes simulados, `CursorHold` chama highlight
  duas vezes; desconectar um resulta em zero chamadas, embora outro cliente
  permaneça compatível.
- **Impacto:** requisições duplicadas e perda dos highlights após detach.
- **Correção proposta:** registrar uma vez por buffer e limpar somente quando
  não restar cliente compatível, após a conclusão do detach.
- **Critério de aceite:** múltiplos clientes não duplicam callbacks; sair um
  deles mantém highlights e sair o último faz a limpeza correta.

## Decisão pendente: alcance da desativação do Blink

Em [lua/plugin/completion.lua](../lua/plugin/completion.lua), o mapping global
de inicialização permanece como fallback do Blink e invoca o dispatcher sem
consultar `config.enabled()`. Foi reproduzido que `vim.b.completion = false`
ainda permite salto local do LuaSnip por Tab. Definir se desativar Blink deve
também desativar os ramos de snippets/Copilot antes de alterar esse contrato.
Essa observação não foi classificada como erro independente.

## Lacuna de cobertura: CSV

[tests/csv.lua](../tests/csv.lua) é uma cópia integral do módulo de produção,
sem assertions ou runner. Substituir por testes de regressão de cache,
callbacks pendentes e múltiplas janelas ao corrigir os achados 7–9.
