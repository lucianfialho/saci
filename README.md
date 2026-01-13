# 🔥 Saci

**Sistema Autônomo de Coding com Inteligência**

Implementação do **Real Ralph Loop** com resiliência avançada e ferramentas de contexto.

## 🚀 Instalação (Global)

```bash
git clone https://github.com/lucianfialho/saci.git
cd saci
chmod +x install.sh
./install.sh
```

Agora você pode usar o comando `saci` em qualquer diretório!

## ⚡ Comandos

| Comando | Descrição |
|---------|-----------|
| `saci scan` | **(Novo)** Detecta stack, pastas e libs do seu projeto automaticamente |
| `saci init` | **(Novo)** Cria um arquivo PRP conversando com você |
| `saci analyze <file>` | **(Novo)** Analisa um arquivo e sugere patterns/hints |
| `saci run` | Inicia o Loop Autônomo (Real Ralph) |

## 🧠 Real Ralph Loop (Blindado)

Diferente do plugin Ralph Wiggum, o Saci:
1.  **Nova Sessão por Task**: Mantém o contexto do Claude sempre limpo (~0 tokens)
2.  **Feedback de Erro**: Lê o erro exato e passa para a próxima tentativa
3.  **Auto-Rollback**: Se falhar, faz `git reset` automático para limpar sujeira
4.  **Memória Externa**: Usa arquivo de progresso para aprender entre sessões

## 📝 Como Usar em um Novo Projeto

```bash
cd meu-projeto

# 1. Detectar contexto
saci scan

# 2. Definir o que fazer
saci init

# 3. Executar
saci run
```

## Estrutura do Projeto

```
saci/
├── templates/        # Templates (prp.json, prompt.md)
├── lib/              # Módulos (scanner, generator, analyzer)
├── saci.sh           # Core script
└── install.sh        # Instalador
```

## Requisitos

- **jq** - parsing JSON
- **Claude Code CLI** - `npm install -g @anthropic-ai/claude-code`
- **Git** - controle de versão

## Licença

MIT
