# 🔥 Saci

**A versão tupiniquim do Ralph**

Saci é um loop autônomo que executa o [Amp](https://ampcode.com) repetidamente até completar todas as tasks. Inspirado no [Ralph](https://github.com/snarktank/ralph), com melhorias de resiliência e ferramentas extras.

> Como o Saci Pererê: travesso, ágil, e resolve problemas do seu jeito.

## 🆚 Saci vs Ralph

| Feature | Ralph | Saci |
|---------|-------|------|
| Loop autônomo | ✅ | ✅ |
| Nova sessão por task | ✅ | ✅ |
| Rollback automático (git reset) | ❌ | ✅ |
| Passa erro anterior pro retry | ❌ | ✅ |
| Scanner de stack | ❌ | ✅ `saci scan` |
| Gerador interativo de PRP | ❌ | ✅ `saci init` |
| Analyzer de patterns | ❌ | ✅ `saci analyze` |
| Safety hooks | ❌ | ✅ Bloqueia comandos perigosos |
| Instalação global | ❌ | ✅ Funciona em qualquer dir |
| Gera AGENTS.md | ❌ | ✅ Auto-detecta contexto |
| Estrutura de tasks | `userStories[]` flat | `features[].tasks[]` hierárquico |

## 🚀 Instalação

```bash
git clone https://github.com/lucianfialho/saci.git
cd saci
chmod +x install.sh
./install.sh
```

Agora você pode usar `saci` em qualquer diretório!

### Requisitos

- [Amp CLI](https://ampcode.com) instalado e autenticado
- `jq` instalado (`brew install jq` no macOS)
- Git

## ⚡ Comandos

| Comando | Descrição |
|---------|-----------|
| `saci scan` | Detecta stack, gera `prp.json` e `AGENTS.md` |
| `saci init` | Cria um PRP conversando com você |
| `saci analyze <file>` | Analisa um arquivo e sugere patterns |
| `saci run` | Inicia o Loop Autônomo |

## 📝 Workflow

```bash
cd meu-projeto

# 1. Detectar contexto do projeto
saci scan

# 2. Planejar feature (usa skill prp)
# No Amp: "skill prp" → responde perguntas → gera prp.json

# 3. Executar
saci run
```

### Opções do Run

```bash
saci run                    # Executa com defaults
saci run --dry-run          # Mostra o que faria sem executar
saci run --prp custom.json  # Usa arquivo PRP diferente
saci run --max-iter 20      # Máximo de iterações (default: 10)
```

## 🧠 Como Funciona

```
┌─────────────────────────────────────────────────────────┐
│                    SACI LOOP                            │
├─────────────────────────────────────────────────────────┤
│  1. Pega próxima task (passes: false)                   │
│  2. Cria checkpoint git                                 │
│  3. Spawna nova sessão Amp (contexto limpo)             │
│  4. Executa task + roda testes                          │
│  5. Se passou → commit + marca passes: true             │
│  6. Se falhou → git reset + guarda erro pro retry       │
│  7. Repete até completar ou max iterações               │
└─────────────────────────────────────────────────────────┘
```

### Resiliência (o diferencial)

- **Nova sessão por task**: Contexto sempre limpo
- **Rollback automático**: `git reset --hard` se falhar
- **Feedback de erro**: Erro exato passa pro próximo retry
- **Memória externa**: `progress.txt` persiste aprendizados

## 📁 Estrutura

```
saci/
├── saci.sh              # Script principal
├── install.sh           # Instalador global
├── lib/
│   ├── scanner.sh       # Detecta stack/libs
│   ├── generator.sh     # Wizard para criar PRP
│   └── analyzer.sh      # Sugere patterns
└── templates/
    ├── prompt.md        # Instruções por iteração
    ├── AGENTS.md        # Template de contexto
    ├── hooks/
    │   ├── hooks.json
    │   └── scripts/
    │       └── safety-check.py
    └── skills/
        ├── prp/         # Skill para gerar PRP
        └── default.md   # Guidelines de execução
```

## 📋 Formato do PRP

```json
{
  "project": {
    "name": "MeuApp",
    "description": "Descrição",
    "branchName": "saci/feature-name"
  },
  "features": [
    {
      "id": "F1",
      "name": "Feature",
      "tasks": [
        {
          "id": "F1-T1",
          "title": "Task title",
          "priority": 1,
          "passes": false,
          "context": {
            "files": ["src/file.ts"],
            "hints": ["Use pattern X"]
          },
          "acceptance": ["Criterion 1", "Typecheck passes"],
          "tests": { "command": "npm test" }
        }
      ]
    }
  ]
}
```

## 🎯 Skill PRP

O Saci instala uma skill no Claude Code para gerar PRPs:

```
> skill prp
> "Quero adicionar sistema de prioridades"

[Saci faz perguntas: 1A, 2B, 3C]
> 1A, 2C, 3B

[Gera: tasks/prp-prioridades.md + prp.json]
```

## 🌐 Verificação Visual de UI (Opcional)

Para tasks de frontend, você pode usar ferramentas que permitem ao Claude verificar a UI no navegador:

| Ferramenta | Tipo | Instalação |
|------------|------|------------|
| **[Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp)** | MCP Server (Google oficial) | Config no `settings.json` |
| **[dev-browser](https://github.com/SawyerHood/dev-browser)** | Plugin/Skill | `/plugin install dev-browser` |

**Chrome DevTools MCP** (recomendado):
```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["chrome-devtools-mcp@latest"]
    }
  }
}
```

Com isso, tasks de UI podem ter no acceptance criteria:
> "Verificar no browser que a mudança funciona"

O Claude abre o navegador, navega, clica, vê erros do console, e valida visualmente.

## 🔒 Safety Hook

Bloqueia comandos perigosos antes de executar:

| Categoria | Exemplos |
|-----------|----------|
| **Destrutivos** | `rm -rf /`, `rm -rf ~`, fork bomb |
| **Arquivos protegidos** | `rm .env`, `rm .git`, `mv prp.json` |
| **Git perigoso** | `git push --force`, `git reset --hard origin/main` |
| **Execução remota** | `curl \| bash`, `wget \| sh` |
| **Package managers** | `npm publish`, `npm unpublish` |
| **Database** | `DROP DATABASE`, `DELETE FROM x;` |
| **Secrets** | `cat .env`, `echo $API_KEY` |

## 🐛 Debug

```bash
# Ver tasks pendentes
cat prp.json | jq '.features[].tasks[] | select(.passes == false) | .title'

# Ver progresso
cat progress.txt

# Dry run
saci run --dry-run
```

## 📚 Referências

- [Ralph (inspiração)](https://github.com/snarktank/ralph)
- [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/)
- [Amp documentation](https://ampcode.com/manual)

## 📄 Licença

MIT
