# Plugins, comandos e integração do tabout

Inventário da configuração ativa em 2026-09-29: **60 plugins instalados**, com fontes conferidas no lock e nos diretórios locais. A captura da configuração completa encontrou **183 comandos globais de usuário**; antes do tabout eram 180. Comandos de buffers também foram examinados em C#, Java, TypeScript, TSX, HTML, Markdown e Lua.

Atualização de 2026-09-30: o comando nativo `:Template` foi removido para impedir sobrescrita; use `:Templates` ou `<leader>st`. O JSON complementar preserva a captura histórica anterior a essa remoção. Os achados ainda pendentes estão em [pendencias-code-review.md](pendencias-code-review.md).

## Tab e Shift-Tab

O tabout é carregado por `lua/plugin/tabout.lua`, com `tabkey = ""`, `backwards_tabkey = ""`, `completion = false` e os dois fallbacks de indentação próprios desativados. O Blink mantém a propriedade dos atalhos; `lua/config/tabout.lua` só tenta navegar em modo de inserção, buffers comuns e com parser disponível.

| Tecla/contexto | Ordem das ações |
| --- | --- |
| Tab em Insert/Select | Menu visível do Blink → Copilot visível → salto local do LuaSnip → tabout (somente Insert) → fallback original |
| Tab antes dos mappings locais do Blink | Mesma precedência anterior → snippet nativo do Neovim → tabout → Tab original |
| Esc em Insert | Sugestão Copilot visível: dispensa e mantém Insert; sem sugestão: fecha o menu do Blink e sai do Insert |
| Ctrl-j / Ctrl-k em Insert | Com menu do Blink aberto: próximo/anterior item; com menu fechado: comportamento nativo ou mapping anterior |
| Alt-k em Insert com LSP compatível | Abre/fecha a assinatura de função; ao abrir, fecha o menu do Blink se necessário |
| Ctrl-Backspace / Ctrl-Delete em Insert | Apaga a palavra para trás/para frente a partir do cursor; Ctrl-Delete no fim da linha mantém o texto anterior |
| Shift-Tab em Insert/Select | Snippet anterior → tabout para trás (somente Insert) → fallback original |
| Tab / Shift-Tab em Normal | `:tabnext` / `:tabprev`, preservados |
| Tab / Shift-Tab no cmdline (`:`, `/`, `?`) | Próxima/anterior sugestão do menu nativo, gerenciado pelo mini.cmdline |
| Prompt, terminal, buffers especiais ou sem parser | O tabout não navega; os handlers anteriores permanecem responsáveis |

Sem sugestão visível do Copilot, ou após rejeitá-la com `Esc`, Tab volta a tentar o salto do LuaSnip quando o menu do Blink estiver fechado.

Alt-k alterna a assinatura do LSP conforme o estado da própria janela. Funciona com o menu de completion do Blink aberto ou fechado, mantém Insert e respeita o fechamento manual até a próxima abertura solicitada. O Blink não instala mapping para Alt-k; Ctrl-k continua selecionando o item anterior de completion.

Ctrl-Backspace apaga até o limite da palavra anterior; no início da linha não faz alterações e, na indentação, remove os espaços anteriores sem juntar linhas. Ctrl-Delete apaga para frente e não faz alterações no fim da linha. Backspace/Delete sem Ctrl mantêm a exclusão de um caractere. A suíte `tests/insert_editing_tui.py` passou 19 casos em terminal real, incluindo palavras parciais, espaços, pontuação, UTF-8 e limites de linha.

Use `:TaboutToggle` para alternar o tabout sem remover os mappings do Blink. O plugin também registra `:Tabout` e `:TaboutBack` (depreciados pelo upstream) e os quatro mappings `<Plug>(Tabout)`, `<Plug>(TaboutBack)`, `<Plug>(TaboutMulti)` e `<Plug>(TaboutBackMulti)`. [API e requisitos oficiais](https://github.com/abecodes/tabout.nvim#more-complex-keybindings).

O adaptador consulta o alvo pelo Tree-sitter e retorna o mapping `<Plug>(Tabout)` ou `<Plug>(TaboutBack)`. O salto executa fora da avaliação da expressão e antes da próxima tecla enfileirada, preservando a ordem de navegação e digitação. O estado global de um snippet antigo do LuaSnip não autoriza saltos fora da região local.

A linha de comando usa a interface nativa `ui2` e a conclusão automática do `mini.cmdline`. O Blink tem `cmdline.enabled = false` para evitar capturar as teclas de navegação de um menu nativo aberto. No cmdline, Tab/Shift-Tab e Ctrl-n/Ctrl-p percorrem sugestões. Com o menu aberto, ↑/↓ e Alt+k/j também percorrem sugestões; com o menu fechado, as setas verticais navegam pelo histórico. As setas horizontais editam o texto. A autocorreção do mini.cmdline fica desativada com `autocorrect.enable = false`. A regressão é coberta por `python3 tests/cmdline_tui.py`, incluindo comandos, buscas com `/` e `?` e o caso `/comm` em um arquivo Lua real.

## Inventário por plugin

A coluna de comandos inclui os definidos nos fontes/documentação instalados. Alguns dependem de setup, FileType ou contexto específico; isso não significa que estejam todos carregados globalmente. Plugins sem comandos próprios são usados por APIs ou mappings. O JSON complementar registra evidências e os comandos efetivamente encontrados na captura.

| Plugin | Uso e estado | Configuração | Comandos disponíveis nos fontes locais |
| --- | --- | --- | --- |
| [aerial.nvim](https://github.com/stevearc/aerial.nvim) | outline e navegação por símbolos; configurado | [lua/plugin/ui.lua](../lua/plugin/ui.lua) | :AerialToggle[!] [left\|right\|float] (após setup)<br>:AerialOpen[!] [left\|right\|float] (após setup)<br>:AerialOpenAll / :AerialClose / :AerialCloseAll / :AerialNext / :AerialPrev / :AerialGo / :AerialInfo / :AerialNavToggle / :AerialNavOpen / :AerialNavClose (após setup) |
| [alpha-nvim](https://github.com/goolord/alpha-nvim) | dashboard inicial; configurado | [lua/plugin/ui.lua](../lua/plugin/ui.lua) | :Alpha / :AlphaRedraw / :AlphaRemap (plugin load) |
| [auto-save.nvim](https://github.com/Pocco81/auto-save.nvim) | salvamento automático ao sair do buffer; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | :ASToggle (plugin load; auto-save configurado enabled) |
| [blink.cmp](https://github.com/saghen/blink.cmp) | completion LSP/path/snippets/Lua API; configurado | [lua/plugin/completion.lua](../lua/plugin/completion.lua) | :BlinkCmp {subcommand} (plugin load; subcomandos validados em plugin/blink-cmp.lua) |
| [bufferline.nvim](https://github.com/akinsho/bufferline.nvim) | linha de buffers; configurado | [lua/plugin/bufferline.lua](../lua/plugin/bufferline.lua), carregado por [lua/plugin/ui.lua](../lua/plugin/ui.lua) | :BufferLinePick / :BufferLinePickClose / :BufferLineCycleNext / :BufferLineCyclePrev / :BufferLineCloseRight / :BufferLineCloseLeft / :BufferLineCloseOthers / :BufferLineMoveNext / :BufferLineMovePrev / :BufferLineSortByExtension / :BufferLineSortByDirectory / :BufferLineSortByRelativeDirectory / :BufferLineSortByTabs / :BufferLineGoToBuffer {n} / :BufferLineTogglePin / :BufferLineTabRename [name] / :BufferLineGroupClose {group} / :BufferLineGroupToggle {group} (após setup) |
| [catppuccin](https://github.com/catppuccin/nvim) | colorscheme alternativo instalado, tema atual é Tokyo Night; instalado sem configuração | — | :Catppuccin {flavour} / :CatppuccinCompile (fonte presente, plugin não carregado/configurado) |
| [Comment.nvim](https://github.com/numToStr/Comment.nvim) | comentários contextuais por Treesitter; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | Sem comando próprio |
| [conform.nvim](https://github.com/stevearc/conform.nvim) | formatting e format-on-save; configurado | [lua/plugin/lsp.lua](../lua/plugin/lsp.lua) | :ConformInfo (plugin load) |
| [copilot.lua](https://github.com/zbirenbaum/copilot.lua) | sugestões inline do Copilot; configurado | [lua/plugin/completion.lua](../lua/plugin/completion.lua) | :Copilot {subcommand} (plugin load; includes auth/status commands per plugin source)<br>Config: :CopilotToggle (lua/plugin/completion.lua) |
| [CopilotChat.nvim](https://github.com/CopilotC-Nvim/CopilotChat.nvim) | chat de GitHub Copilot, instalado sem setup; instalado sem configuração | — | :CopilotChat [input] (plugin command; setup ausente)<br>:CopilotChatPrompts (plugin command)<br>:CopilotChatModels (plugin command)<br>:CopilotChatOpen / :CopilotChatClose / :CopilotChatToggle / :CopilotChatStop / :CopilotChatReset (plugin commands)<br>:CopilotChatSave [path] / :CopilotChatLoad [path] (plugin commands) |
| [csvview.nvim](https://github.com/hat0uma/csvview.nvim) | renderização de tabela CSV e preview grande; configurado | [lua/plugin/csv.lua](../lua/plugin/csv.lua) | :CsvViewEnable [options] / :CsvViewDisable / :CsvViewToggle [options] / :CsvViewInfo (plugin load) |
| [fidget.nvim](https://github.com/j-hui/fidget.nvim) | progresso LSP; configurado | [lua/plugin/lsp.lua](../lua/plugin/lsp.lua) | :Fidget {subcommand} (após setup) |
| [flash.nvim](https://github.com/folke/flash.nvim) | busca e salto por texto; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | Sem comando próprio |
| [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) | hunks, blame, diff e staging; configurado | [lua/plugin/git.lua](../lua/plugin/git.lua) | :Gitsigns {subcommand} (plugin load; command interface) |
| [guess-indent.nvim](https://github.com/NMAC427/guess-indent.nvim) | detecção de indentação; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | :GuessIndent (plugin load) |
| [hunk.nvim](https://github.com/julienvincent/hunk.nvim) | editor visual de diff por :DiffEditor; instalado sem setup; instalado sem configuração | — | :DiffEditor {left} {right} [output] (plugin load; instalado sem setup) |
| [image.nvim](https://github.com/3rd/image.nvim) | renderização de imagens em notebooks; configurado | [lua/plugin/notebook.lua](../lua/plugin/notebook.lua) | :ImageReport (plugin load) |
| [img-clip.nvim](https://github.com/HakonHarnes/img-clip.nvim) | colar imagens da área de transferência; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | :PasteImage [options] / :ImgClipConfig / :ImgClipDebug (plugin load) |
| [indent-blankline.nvim](https://github.com/lukas-reineke/indent-blankline.nvim) | guias de indentação; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | :IBLEnable / :IBLDisable / :IBLToggle / :IBLEnableScope / :IBLDisableScope / :IBLToggleScope (after/plugin, quando carregado) |
| [Ionide-vim](https://github.com/ionide/Ionide-vim) | suporte F# e integração Ionide; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | :Log {message} (definido pelo ftplugin F#; filetype/condicional) |
| [jupytext.nvim](https://github.com/GCBallesteros/jupytext.nvim) | conversão/edição de notebooks Jupyter; configurado | [lua/plugin/notebook.lua](../lua/plugin/notebook.lua) | Sem comando próprio |
| [lazydev.nvim](https://github.com/folke/lazydev.nvim) | bibliotecas e completion da API Lua de Neovim; configurado | [lua/plugin/completion.lua](../lua/plugin/completion.lua) | :LazyDev (após setup; informação/configuração LazyDev) |
| [lazygit.nvim](https://github.com/kdheepak/lazygit.nvim) | interface LazyGit em terminal; configurado | [lua/plugin/git.lua](../lua/plugin/git.lua) | :LazyGit / :LazyGitLog / :LazyGitCurrentFile / :LazyGitFilter / :LazyGitFilterCurrentFile / :LazyGitConfig (plugin load) |
| [lsp-grammarly](https://github.com/emacs-grammarly/lsp-grammarly) | servidor LSP Grammarly; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | Sem comando próprio |
| [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) | statusline; configurado | [lua/plugin/ui.lua](../lua/plugin/ui.lua) | :LualineBuffersJump / :LualineNotices / :LualineRenameTab (comandos do plugin; conforme suporte da versão) |
| [LuaSnip](https://github.com/L3MON4D3/LuaSnip) | engine de snippets e saltos locais; configurado | [lua/plugin/completion.lua](../lua/plugin/completion.lua) | :LuaSnipUnlinkCurrent (após plugin load)<br>:LuaSnipListAvailable (após plugin load) |
| [mason-tool-installer.nvim](https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim) | instalação de ferramentas LSP configuradas; configurado | [lua/plugin/lsp.lua](../lua/plugin/lsp.lua) | :MasonToolsInstall / :MasonToolsInstallSync / :MasonToolsUpdate / :MasonToolsUpdateSync / :MasonToolsClean (plugin load) |
| [mason.nvim](https://github.com/mason-org/mason.nvim) | gerenciador de ferramentas LSP; configurado | [lua/plugin/lsp.lua](../lua/plugin/lsp.lua) | :Mason / :MasonInstall {pkg} / :MasonUninstall {pkg} / :MasonUninstallAll / :MasonUpdate / :MasonLog (plugin load) |
| [mini.nvim](https://github.com/echasnovski/mini.nvim) | ícones, textobjects, surround, cmdline e diff; configurado | [lua/plugin/ui.lua](../lua/plugin/ui.lua) | :Pick {picker} / :WithPreview {picker} (após setup do mini.pick, não configurado); :Git {action} (após setup do mini.git, não configurado); :Colorscheme {name} (após setup mini.colors, não configurado); :Man {page} (módulo opcional) |
| [modicator.nvim](https://github.com/mawkler/modicator.nvim) | cor da linha do cursor conforme modo; configurado | [lua/plugin/ui.lua](../lua/plugin/ui.lua) | Sem comando próprio |
| [molten-nvim](https://github.com/benlubas/molten-nvim) | execução de células e outputs Jupyter; configurado | [lua/plugin/notebook.lua](../lua/plugin/notebook.lua) | :MoltenInfo / :MoltenInit [shared] [kernel] / :MoltenDeinit / :MoltenGoto [n] / :MoltenNext [n] / :MoltenPrev [n]<br>:MoltenEvaluateLine [kernel] / :MoltenEvaluateVisual [kernel] / :MoltenEvaluateOperator [kernel] / :MoltenEvaluateArgument [kernel] code / :MoltenReevaluateCell<br>:MoltenDelete[!] / :MoltenShowOutput / :MoltenHideOutput / :MoltenEnterOutput / :MoltenInterrupt [kernel]<br>:MoltenOpenInBrowser / :MoltenImagePopup / :MoltenRestart[!] [kernel] / :MoltenSave [path] [kernel] / :MoltenLoad [shared] [path]<br>:MoltenExportOutput[!] [path] [kernel] / :MoltenImportOutput [path] [kernel] / :MoltenYankOutput[!]<br>Config: :NotebookHealth / :NewNotebook [path] (notebook.lua; shared notebook module) |
| [neoscroll.nvim](https://github.com/karb94/neoscroll.nvim) | rolagem animada; configurado | [lua/plugin/ui.lua](../lua/plugin/ui.lua) | :NeoscrollEnablePM / :NeoscrollDisablePM / :NeoscrollEnableBufferPM / :NeoscrollDisableBufferPM / :NeoscrollEnableGlobalPM / :NeoscrollDisableGlobalPM / :NeoscrollDisablGlobalePM (inclui typo legado do fonte; setup condicional) |
| [nui.nvim](https://github.com/MunifTanjim/nui.nvim) | biblioteca de componentes UI; dependência transitiva; dependencia | — | Sem comando próprio |
| [nvim-autopairs](https://github.com/windwp/nvim-autopairs) | pares automáticos; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | Sem comando próprio |
| [nvim-highlight-colors](https://github.com/brenoprata10/nvim-highlight-colors) | realce de valores de cor; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | :HighlightColors (após setup) |
| [nvim-hlslens](https://github.com/kevinhwang91/nvim-hlslens) | marcadores de posição de busca; configurado | [lua/plugin/ui.lua](../lua/plugin/ui.lua) | :HlSearchLensToggle / :HlSearchLensEnable / :HlSearchLensDisable (plugin load) |
| [nvim-lint](https://github.com/mfussenegger/nvim-lint) | lint por filetype; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | Sem comando próprio |
| [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) | configuração de servidores LSP nativos; configurado | [lua/plugin/lsp.lua](../lua/plugin/lsp.lua) | :LspInfo / :LspLog / :LspRestart / :LspStart / :LspStop (runtime/plugin load) |
| [nvim-scrollbar](https://github.com/petertriho/nvim-scrollbar) | barra de rolagem com sinais; configurado | [lua/plugin/ui.lua](../lua/plugin/ui.lua) | :ScrollbarShow / :ScrollbarHide / :ScrollbarToggle (plugin load) |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | instalação de parsers e suporte Treesitter nativo; configurado | [lua/plugin/syntax.lua](../lua/plugin/syntax.lua) | :TSInstall {lang} / :TSInstallFromGrammar {lang} / :TSLog / :TSUninstall {lang} / :TSUpdate [lang...] (plugin load; versão nvim-treesitter atual) |
| [nvim-treesitter-context](https://github.com/nvim-treesitter/nvim-treesitter-context) | contexto estrutural no topo; configurado | [lua/plugin/syntax.lua](../lua/plugin/syntax.lua) | :TSContext (após setup) |
| [nvim-ts-autotag](https://github.com/windwp/nvim-ts-autotag) | fechamento/renomeação automática de tags; configurado | [lua/plugin/syntax.lua](../lua/plugin/syntax.lua) | Sem comando próprio |
| [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) | ícones usados por Snacks, bufferline e interfaces; configurado | [lua/plugin/01-snack.lua, lua/plugin/ui.lua](../lua/plugin/01-snack.lua, lua/plugin/ui.lua) | :NvimWebDeviconsHiTest (debug command) |
| [oil.nvim](https://github.com/stevearc/oil.nvim) | gerenciador de arquivos em buffer; configurado | [lua/plugin/ui.lua](../lua/plugin/ui.lua) | :Oil [path] (plugin load) |
| [otter.nvim](https://github.com/jmbuhr/otter.nvim) | LSPs para código embutido em notebooks; configurado | [lua/plugin/notebook.lua](../lua/plugin/notebook.lua) | :OtterActivate / :OtterDeactivate / :OtterExport / :OtterExportAs {path} (plugin load) |
| [pdfreader.nvim](https://github.com/r-pletnev/pdfreader.nvim) | leitura de PDF; configurado | [lua/plugin/pdfreader.lua](../lua/plugin/pdfreader.lua) | :PDFReader {subcommand} (após setup; config aborta se Poppler ausente) |
| [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) | biblioteca/utilitários Lua; dependência transitiva; dependencia | — | :PlenaryBustedFile {file} / :PlenaryBustedDirectory {dir} (comandos de teste) |
| [quarto-nvim](https://github.com/quarto-dev/quarto-nvim) | execução de células Quarto/Jupyter; configurado | [lua/plugin/notebook.lua](../lua/plugin/notebook.lua) | :QuartoPreview [args] / :QuartoPreviewNoWatch [args] / :QuartoUpdatePreview [args] / :QuartoClosePreview / :QuartoActivate / :QuartoHelp {query} (plugin load); :QuartoSend / :QuartoSendAbove / :QuartoSendBelow / :QuartoSendAll / :QuartoSendRange / :QuartoSendLine (após quarto setup) |
| [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) | renderização Markdown; configurado | [lua/plugin/markdown.lua](../lua/plugin/markdown.lua) | :RenderMarkdown [method] [bool] (registrado pelo setup; methods documentados dinamicamente como enable/disable/toggle/buf_enable/buf_disable/buf_toggle/preview/log/expand/contract/debug/config; chamadas dependem API disponível) |
| [snacks.nvim](https://github.com/folke/snacks.nvim) | picker, explorer, terminal, zen e utilitários; configurado | [lua/plugin/01-snack.lua](../lua/plugin/01-snack.lua) | Sem comando próprio |
| [suda.vim](https://github.com/lambdalisue/suda.vim) | leitura/gravação de arquivos com privilégios elevados; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | :SudaRead [file] / :SudaWrite [file] (plugin load) |
| [tabout.nvim](https://github.com/abecodes/tabout.nvim) | salto além de delimitadores; instalado sem setup; configurado | [lua/plugin/tabout.lua](../lua/plugin/tabout.lua) | :Tabout / :TaboutBack (deprecated); :TaboutToggle (registrado apenas após setup) |
| [template.nvim](https://github.com/nvimdev/template.nvim) | templates de arquivo; configurado | [lua/plugin/templates.lua](../lua/plugin/templates.lua) | :Templates [lang\|all] / <leader>st (fluxo seguro da configuração); :Template nativo removido para evitar sobrescrita |
| [todo-comments.nvim](https://github.com/folke/todo-comments.nvim) | realce/navegação de TODO/FIXME; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | :TodoQuickFix / :TodoLocList / :TodoTrouble / :TodoTelescope / :TodoFzfLua (dependem integração correspondente) |
| [tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | colorscheme ativo Tokyo Night; configurado | [lua/plugin/00-colorscheme.lua](../lua/plugin/00-colorscheme.lua) | Sem comando próprio |
| [trouble.nvim](https://github.com/folke/trouble.nvim) | painel de diagnósticos e símbolos; configurado | [lua/plugin/ui.lua](../lua/plugin/ui.lua) | :Trouble {mode} {action} [opts] (após setup/plugin load) |
| [undotree](https://github.com/mbbill/undotree) | histórico persistente de undo; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | :UndotreeToggle / :UndotreeShow / :UndotreeHide / :UndotreeFocus / :UndotreePersistUndo (plugin load) |
| [vim-prisma](https://github.com/prisma/vim-prisma) | filetype e sintaxe Prisma; configurado | [lua/plugin/syntax.lua](../lua/plugin/syntax.lua) | Sem comando próprio |
| [vim-visual-multi](https://github.com/mg979/vim-visual-multi) | edição multicursor; configurado | [lua/plugin/editor.lua](../lua/plugin/editor.lua) | :VMFilterLines / :VMFilterRegions / :VMRegionsToBuffer / :VMMassTranspose / :VMQfix / :VMSort (comandos buffer-local/condicionais da sessão VM) |
| [which-key.nvim](https://github.com/folke/which-key.nvim) | janela de ajuda de mappings; configurado | [lua/plugin/ui.lua](../lua/plugin/ui.lua) | :WhichKey [keys] (plugin load) |

## Atalhos específicos da configuração

| Plugin | Atalhos/contextos |
| --- | --- |
| aerial.nvim | Normal <leader>v → :AerialToggle! |
| alpha-nvim | Dashboard setup; no custom mappings. |
| auto-save.nvim | No custom mappings. |
| blink.cmp | Insert <Tab>: visible menu accept → Copilot accept → local LuaSnip jump → tabout → fallback. Config also installs global Insert <Tab> for startup and Blink fallback. Default preset includes Insert <S-Tab> snippet_backward. Insert <Esc> dismisses visible Copilot suggestions while retaining Insert; otherwise hides completion and exits Insert. Insert <C-j>/<C-k> select next/previous item only while the Blink menu is visible; otherwise use the prior mapping/native behavior. |
| bufferline.nvim | Barra sempre visível. O “x” e o clique direito fecham o buffer clicado usando `config.buffers.close`, preservando o layout e recusando alterações não salvas. |
| catppuccin | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| Comment.nvim | No plugin default mappings retained by config; see configured mapping. |
| conform.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| copilot.lua | Config Insert accept: <Tab> dispatched by Blink; accept_word <C-Right>; dismiss <Esc> dispatched by Blink/global fallback; plugin accept/dismiss defaults disabled; Normal <leader>ca auth and <leader>ct toggle.<br>Config Normal <leader>ct toggles inline suggestions; <leader>ca authenticates. |
| CopilotChat.nvim | Plugin default chat-buffer Insert <Tab> (inactive because no setup); possible conflict if chat is configured. |
| csvview.nvim | Normal <leader>mc toggles CSV rendering globally. |
| fidget.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| flash.nvim | Normal/Visual <leader>fk forward and <leader>fK backward search. |
| gitsigns.nvim | Normal <leader>gs/gr/gS/gR/gp/gl/gd/gb/gw for hunk stage/reset, buffer stage/reset, preview, blame, diff, blame toggle, word diff. |
| guess-indent.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| hunk.nvim | No config/mappings; config <leader>gh runs external `hunk diff --watch`, not this plugin. |
| image.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| img-clip.nvim | No custom mapping; plugin commands remain available. |
| indent-blankline.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| Ionide-vim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| jupytext.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| lazydev.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| lazygit.nvim | Normal <leader>gg → :LazyGit. |
| lsp-grammarly | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| lualine.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| LuaSnip | Plugin <Plug> Insert mappings: expand-or-jump, expand-snippet, next-choice, prev-choice, jump-next, jump-prev; config delegates forward jump through Blink on <Tab>. |
| mason-tool-installer.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| mason.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| mini.nvim | Configured icons, ai, surround, cmdline autocomplete, diff; no custom mappings. |
| modicator.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| molten-nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| neoscroll.nvim | Normal <C-u>/<C-d> smooth scroll; no Insert mappings. |
| nui.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| nvim-autopairs | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| nvim-highlight-colors | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| nvim-hlslens | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| nvim-lint | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| nvim-lspconfig | LSP buffer-local grn/gra/H/gK/grr/gri/grd/grD/gO/gW/grt; Insert <A-k> toggles native signature help, closing the Blink menu when open; Insert <C-k> navigates to the previous Blink item; global <leader>= format. |
| nvim-scrollbar | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| nvim-treesitter | No custom mapping; parser install and FileType setup. |
| nvim-treesitter-context | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| nvim-ts-autotag | Insert > custom close/void-tag handler in supported filetypes. |
| nvim-web-devicons | Sem mappings próprios; dependência visual usada por Snacks/UI. |
| oil.nvim | Normal - open parent dir; <leader>o toggle float; buffer q/Esc close; <C-l>/<C-j> disabled; <M-h> split. |
| otter.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| pdfreader.nvim | No custom mapping; PDF filetype activation. |
| plenary.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| quarto-nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| render-markdown.nvim | Normal <leader>mm global toggle; <leader>mb buffer toggle. |
| snacks.nvim | Normal picker/explorer/zen mappings: <leader>sh,sk,sc,sf,fe,ff,ss,sw,fg,fp,sd,sg,sr,s.,<leader><leader>,<leader>/,s/,sn and <C-\>. |
| suda.vim | Sem mappings próprios configurados; comandos :SudaRead e :SudaWrite disponíveis. |
| tabout.nvim | Tab/Shift-Tab via Blink; mappings automáticos do tabout desativados |
| template.nvim | Normal <leader>st opens template picker. |
| todo-comments.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| tokyonight.nvim | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| trouble.nvim | Normal <leader>xx diagnostics; <leader>xX current-buffer diagnostics; <leader>xs symbols. |
| undotree | No config mapping; comment says mapped to <F5> but no <F5> registration in lua/plugin/editor.lua. |
| vim-prisma | Sem mapping específico definido na configuração; verificar defaults documentados no plugin. |
| vim-visual-multi | Plugin default <C-n> starts/adds cursors (plugin mapping, may interact with editor mappings). |
| which-key.nvim | No mappings added; registers <leader>s and <leader>g groups. |

## Comandos próprios da configuração

`CopilotToggle`, `Templates`, `NotebookHealth`, `NewNotebook`, `PackAdd`, `PackDel` e `PackUpdate` continuam disponíveis. O suporte nativo de LSP e os atalhos de diagnóstico/formatação permanecem em `lua/plugin/lsp.lua`.

`<leader>w` salva e fecha o buffer atual; `<leader>q` fecha apenas se não houver alterações não salvas. Ambos preservam as janelas e a lateral do explorer do Snacks enquanto houver outros buffers de edição listados, inclusive descarregados. Ao fechar o último, encerram a sessão com `qall`, sem criar um buffer vazio. Alterações não salvas continuam impedindo a saída.

O “x” e o clique direito do Bufferline compartilham essa lógica de fechamento em `lua/config/buffers.lua`, usando o ID do buffer clicado. Isso também vale para buffers em segundo plano e quando o foco está no explorer. O último buffer encerra a sessão; buffers modificados precisam ser salvos ou descartados explicitamente.

## Reprodução da captura e dos testes

```sh
NVIM_LOG_FILE=/tmp/nvim-plugin-audit.log nvim --headless -i NONE --cmd "luafile scripts/plugin_audit.lua" -c 'lua vim.defer_fn(function() PluginAudit.write("/tmp/neovim-plugins.json"); vim.cmd("qa!") end,300)'
NVIM_LOG_FILE=/tmp/nvim-tabout-tests.log nvim --headless -n -i NONE -c 'luafile tests/tabout.lua'
python3 tests/tabout_tui.py
python3 tests/signature_tui.py
python3 tests/insert_editing_tui.py
python3 tests/buffer_closing.py
NVIM_LOG_FILE=/tmp/nvim-template-command-tests.log nvim --headless -n -u NONE -i NONE -l tests/templates_command.lua
```

A comparação antes/depois preservou todos os 180 comandos existentes e os mappings globais anteriores. Acrescentou apenas os três comandos e os quatro `<Plug>` do tabout. Nos sete filetypes capturados, as diferenças locais ficaram em Tab/Shift-Tab do Blink, nos modos Insert e Select.

Os pacotes CopilotChat, Catppuccin e hunk estão instalados sem configuração direta. Isso distingue CopilotChat do Copilot inline. O mapping `<leader>gh` chama o executável externo `hunk diff --watch`; o plugin `hunk.nvim` fornece `:DiffEditor` e não esse executável. Nenhum desses pacotes foi ativado para instalar tabout.

[Inventário estruturado com evidências](neovim-plugins.json).

Validação de Tab e navegação em 2026-09-30: 21 casos de precedência e 38 cenários com teclas reais passaram, incluindo snippets antigos fora da região local, Tab/Shift-Tab seguidos de texto na mesma fila e Ctrl-j/Ctrl-k com o menu aberto/fechado. O teste de Copilot usa o mecanismo real de exibição/aceitação com uma sugestão determinística, sem consultar o serviço remoto. O menu do Blink também usa um provedor determinístico. Os demais cenários usam os parsers e LuaSnip instalados. Isso cobre os conflitos de atalhos e os fluxos exercitados; não equivale a testar todas as funcionalidades de cada plugin.
