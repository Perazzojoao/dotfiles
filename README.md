# Dotfiles

Configurações pessoais gerenciadas com [GNU Stow](https://www.gnu.org/software/stow/).
Cada diretório na raiz é um **pacote Stow** e reproduz a estrutura esperada
dentro do diretório pessoal (`~`). O Stow mantém os arquivos neste repositório
e cria links simbólicos nos destinos reais.

## Requisitos

- GNU Stow instalado e disponível no `PATH`.
- Git para versionar e revisar alterações, especialmente ao usar `--adopt`.
- O repositório clonado diretamente em `~/dotfiles`. Nessa posição, o destino
  padrão do Stow é `~`, que é o diretório pai do repositório.

Confirme o ambiente antes de operar:

```bash
cd ~/dotfiles
stow --version
git status --short
```

## Mapeamento das configurações

```text
dotfiles/
├── README.md
├── zsh/                              # pacote: shell Zsh
│   └── .zshrc                        # → ~/.zshrc
├── nvim/                             # pacote: Neovim
│   ├── .stow-local-ignore            # exclusões locais do pacote
│   └── .config/nvim/                 # → ~/.config/nvim/
│       ├── .gitignore
│       ├── init.lua                  # ponto de entrada
│       ├── nvim-pack-lock.json       # versões dos plugins
│       ├── lua/
│       │   ├── config/
│       │   │   ├── autocmds.lua
│       │   │   ├── copilot_completion.lua
│       │   │   ├── keymaps.lua
│       │   │   ├── options.lua
│       │   │   └── pack.lua
│       │   ├── plugin/
│       │   │   ├── 00-colorscheme.lua
│       │   │   ├── 01-snack.lua
│       │   │   ├── completion.lua
│       │   │   ├── csv.lua
│       │   │   ├── editor.lua
│       │   │   ├── git.lua
│       │   │   ├── lsp.lua
│       │   │   ├── markdown.lua
│       │   │   ├── pdfreader.lua
│       │   │   ├── syntax.lua
│       │   │   └── ui.lua
│       │   └── snippets/
│       │       ├── react.lua
│       │       └── typescript.lua
│       └── tests/
│           └── csv.lua
├── agents/                           # pacote: skills de agentes
│   ├── .stow-local-ignore            # exclusões locais do pacote
│   └── .agents/                      # → ~/.agents/
│       ├── .skill-lock.json
│       └── skills/
│           ├── design-patterns/      # 5 arquivos
│           ├── dry-refactoring/      # 1 arquivo
│           ├── find-docs/            # 1 arquivo
│           ├── find-skills/          # 1 arquivo
│           ├── gh-cli/               # 1 arquivo
│           ├── graphify/             # 10 arquivos
│           ├── jest/                 # 41 arquivos
│           ├── jscpd/                # 1 arquivo
│           ├── jupyter-notebook/     # 12 arquivos
│           ├── playwright-cli/       # 10 arquivos
│           ├── shadcn-ui/            # 10 arquivos
│           ├── skill-creator/         # 19 arquivos
│           ├── terraform-skill/       # 9 arquivos
│           └── use-railway/           # 25 arquivos
└── herdr/                            # pacote: Herdr
    ├── .stow-local-ignore            # exclui estado de execução
    └── .config/herdr/                # → ~/.config/herdr/
        ├── config.toml               # interface, teclas, som e comandos
        ├── bin/
        │   ├── paplay                # compatibilidade de áudio
        │   └── windows-toast.ps1      # notificações no Windows/WSL
        ├── sounds/
        │   ├── done.mp3
        │   └── request.mp3
        └── plugins/config/
            ├── cloudmanic.herdr-plus/
            │   ├── quick-actions/
            │   │   ├── open-reviewr.toml
            │   │   └── open-working-dir.toml
            │   └── worktrees/
            │       └── default.toml
            ├── persiyanov.reviewr/
            │   └── config.toml
            └── worktree-hooks/
                └── config.toml
```

Os 147 arquivos de `agents/.agents/skills/` estão organizados, conforme cada
skill, entre `SKILL.md`, `AGENTS.md`, `README.md`, `references/`, `rules/`,
`scripts/`, `agents/`, `assets/`, `examples/`, `resources/` e `eval-viewer/`.
Também existem arquivos auxiliares versionados como lock, licença, manifesto,
notebooks, imagens e templates.

Os arquivos `.stow-local-ignore` não são instalados no diretório pessoal. Eles
mantêm fora do gerenciamento metadados de Git, arquivos temporários e estados
específicos desta máquina, como `nvim.log`, `.codex`, `.pi`, `__pycache__` e
configurações locais em `.claude`. No Herdr, também ficam locais os clones de
plugins, logs, sockets, sessões, notas de release, locks transitórios e o
registro `plugins.json`, que contém caminhos absolutos da máquina.

## Fluxo seguro do Stow

Execute todos os comandos a partir de `~/dotfiles`. A regra deste repositório é
sempre planejar com `--simulate --verbose` antes de aplicar a mesma operação sem
`--simulate`.

### Planejar e aplicar um pacote

```bash
# Planejar
stow --simulate --verbose nvim

# Aplicar somente depois de revisar a saída
stow --verbose nvim
```

Para vários pacotes:

```bash
stow --simulate --verbose zsh nvim agents herdr
stow --verbose zsh nvim agents herdr
```

Uma simulação bem-sucedida termina com o aviso de que o modo de simulação não
modificou o sistema. Mensagens de conflito devem ser resolvidas antes da
aplicação; não use `--override` como correção automática.

### Remover os links de um pacote

`--delete` remove apenas os links pertencentes ao pacote. Os arquivos continuam
armazenados neste repositório.

```bash
# Planejar a remoção
stow --simulate --verbose --delete nvim

# Remover os links
stow --verbose --delete nvim
```

Para restaurá-los depois:

```bash
stow --simulate --verbose nvim
stow --verbose nvim
```

### Reaplicar um pacote

Use `--restow` depois de adicionar, mover ou remover arquivos dentro de um
pacote. A operação equivale a remover e instalar novamente os links daquele
pacote.

```bash
stow --simulate --verbose --restow nvim
stow --verbose --restow nvim
```

## Adicionar configurações

### Arquivo que ainda não existe no destino

Crie-o dentro do pacote reproduzindo o caminho relativo à home. Para um arquivo
que deverá existir como `~/.config/example/config.toml`:

```text
dotfiles/
└── example/
    └── .config/
        └── example/
            └── config.toml
```

Depois planeje e aplique:

```bash
stow --simulate --verbose example
stow --verbose example
```

### Arquivo que já existe no destino

Não apague nem sobrescreva o original. Primeiro copie-o para o caminho
equivalente no pacote e confirme que as duas cópias são idênticas:

```bash
cmp ~/.config/example/config.toml \
  ~/dotfiles/example/.config/example/config.toml
```

Então simule a adoção:

```bash
stow --simulate --verbose --adopt example
```

Revise especialmente as ações `MV` e `LINK`. Se estiverem corretas, aplique e
confira imediatamente a alteração versionada:

```bash
stow --verbose --adopt example
git diff -- example
git status --short
```

`--adopt` move o conteúdo existente no destino para o pacote. Por isso ele só
deve ser usado depois da simulação e com o repositório sob controle de versão.

## Remover um arquivo do gerenciamento

Para retirar apenas um arquivo de um pacote, remova-o do pacote e reaplique o
pacote. Antes de apagar, confirme o caminho exato e mantenha uma cópia ou um
commit recuperável.

```bash
# Remover do repositório com histórico recuperável
git rm -- nvim/.config/nvim/caminho/exato.lua

# Planejar e aplicar a atualização dos links
stow --simulate --verbose --restow nvim
stow --verbose --restow nvim
git status --short
```

Se a intenção for apenas parar de usar temporariamente todas as configurações de
um pacote, prefira `--delete`; não remova os arquivos do repositório.

## Verificações úteis

```bash
# Mostrar para onde um link aponta
readlink -f ~/.zshrc

# Verificar todos os links simbólicos gerenciados na home
find ~ -maxdepth 4 -type l -lname '*dotfiles*' -print

# Validar que os pacotes já aplicados não exigem mudanças
stow --simulate --verbose zsh nvim agents herdr

# Revisar alterações antes de versionar
git diff --check
git status --short
```

## Referência

- [Manual oficial do GNU Stow](https://www.gnu.org/software/stow/manual/stow.html)
- [Página oficial do GNU Stow](https://www.gnu.org/software/stow/)
