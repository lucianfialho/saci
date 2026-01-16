# Claude Code Interactive Mode

> Features do modo interativo que podem inspirar melhorias no Saci
> Fonte: https://code.claude.com/docs/en/interactive-mode.md

---

## 🎯 Features Relevantes para Saci

### 1. **Bash Mode com `!` prefix**
```bash
! npm test
! git status
! ls -la
```

**Comportamento:**
- Roda comando direto sem Claude interpretar
- Adiciona output ao contexto da conversa
- Suporta `Ctrl+B` para background

**Relevância Saci:** 🤔 Médio - Saci já roda bash direto, mas poderia ter modo interativo

---

### 2. **Background Bash Commands** 🌟
```bash
Ctrl+B  # Move comando para background
```

**Como funciona:**
- Comandos rodam assincronamente
- Retorna task ID imediatamente
- Output pode ser retrievado com BashOutput tool
- Auto cleanup ao sair

**Comandos comuns em background:**
- Build tools (webpack, vite, make)
- Dev servers
- Test runners longos
- Docker, terraform

**Relevância Saci:** 🌟🌟 **ALTO** - Saci poderia rodar testes em background!

**API disponível:**
```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "npm run build",
    "run_in_background": true
  }
}
```

---

### 3. **Reverse Search (Ctrl+R)**
- Busca interativa no history
- Press `Ctrl+R` repetidamente para navegar matches
- Press `Tab` ou `Esc` para aceitar

**Relevância Saci:** ⚠️ Baixa - Saci não tem modo interativo user-facing

---

### 4. **Verbose Output Toggle (Ctrl+O)**
- Mostra detalhes de execução de tools
- Útil para debug

**Relevância Saci:** 🌟 **ÚTIL** - Já existe via `--verbose` flag

---

### 5. **Command History**
- History stored per working directory
- Cleared com `/clear`
- History expansion (`!`) disabled por padrão

**Relevância Saci:** ⚠️ Baixa - Saci não é interativo

---

## 💡 Insights para o Saci

### **Background Task Support**

Poderia adicionar ao Saci:
```bash
# saci.sh - Run tests in background
cat prompt.md | claude \
  --dangerously-skip-permissions \
  --append-system-prompt "You can run long commands in background using run_in_background: true parameter"
```

**Benefício:** Testes longos não bloqueariam o loop!

**Exemplo prompt.md:**
```markdown
Run tests in background so you can continue working on other tasks.
Use `run_in_background: true` in Bash tool for long-running commands.
```

---

### **Bash Mode com `!`**

Conceito interessante mas **não aplicável** ao Saci (não tem modo interativo user-facing).

---

### **Environment Variable CLAUDE_CODE_DISABLE_BACKGROUND_TASKS**

```bash
export CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1
```

Disable all background task functionality.

**Relevância Saci:** Se implementarmos background tasks, ter essa flag de disable.

---

## 📊 Resumo de Relevância

| Feature | Relevância | Aplicável ao Saci? |
|---------|------------|-------------------|
| **Background tasks** | 🌟🌟🌟 | ✅ SIM - Muito útil! |
| **Bash mode !** | ⚠️ | ❌ Não aplicável (Saci não é interativo) |
| **Ctrl+O verbose** | 🌟 | ✅ Já existe via --verbose |
| **History** | ⚠️ | ❌ Não aplicável |
| **Reverse search** | ⚠️ | ❌ Não aplicável |

---

## 🚀 Action Items para Saci

1. **Considerar implementar background task support**
   - Útil para: builds longos, test suites grandes
   - API: `run_in_background: true` no Bash tool
   - Retrieving output: BashOutput tool

2. **Já temos verbose mode** via `--verbose` flag ✅

---

## 📚 Links

- [CLI Reference](./cli-reference.md) - Flags e comandos
- [Hooks](./hooks.md) - Event handlers
