# Claude Code CLI Reference

> Documentação completa do CLI do Claude Code
> Fonte: https://code.claude.com/docs/en/cli-reference.md

---

## 🎯 Comandos Principais

| Comando | Descrição | Exemplo |
|---------|-----------|---------|
| `claude` | Inicia REPL interativo | `claude` |
| `claude "query"` | Inicia REPL com prompt inicial | `claude "explain this project"` |
| `claude -p "query"` | Query via SDK e sai | `claude -p "explain this function"` |
| `cat file \| claude -p "query"` | Processa conteúdo via pipe | `cat logs.txt \| claude -p "explain"` |
| `claude -c` | Continua conversa mais recente | `claude -c` |
| `claude -r "<session>"` | Resume sessão por ID ou nome | `claude -r "auth-refactor"` |
| `claude update` | Atualiza para última versão | `claude update` |

---

## 🚀 Flags Críticas para Saci

### **Print Mode (SDK Mode)**
```bash
claude -p "query"  # Modo não-interativo (o que Saci usa)
```

**Flags relacionadas:**
- `--output-format json` - Output estruturado (útil para parsing)
- `--output-format stream-json` - Streaming de eventos
- `--max-turns 10` - Limita turns (igual MAX_ITERATIONS do Saci)
- `--verbose` - Logging completo turn-by-turn (útil para debug)

### **Permission Management**
```bash
--dangerously-skip-permissions  # Skip permission prompts (Saci usa isso!)
--allowedTools "Bash(git*)" "Read"  # Pre-approve tools específicos
--disallowedTools "Edit" "Write"  # Bloqueia tools
--tools "Bash,Edit,Read"  # Restringe a apenas esses tools
```

### **System Prompt Customization**
```bash
--system-prompt "text"  # SUBSTITUI prompt inteiro
--system-prompt-file file.txt  # Carrega de arquivo (print mode only)
--append-system-prompt "text"  # ADICIONA ao prompt default ✅ RECOMENDADO
```

**Quando usar cada um:**
- `--system-prompt`: Controle total (remove instruções default)
- `--system-prompt-file`: Carregar de arquivo (versionamento)
- `--append-system-prompt`: **Melhor para maioria dos casos** (mantém capabilities)

### **Session Management**
```bash
--continue, -c  # Continua última conversa no diretório
--resume, -r "session-id"  # Resume sessão específica
--session-id "uuid"  # Usa session ID específico
--fork-session  # Cria novo ID ao resumir (não reusa original)
```

### **Debug & Development**
```bash
--debug "api,hooks"  # Debug mode com filtros
--verbose  # Logging completo (útil com -p)
--include-partial-messages  # Inclui eventos de streaming
```

### **Working Directory**
```bash
--add-dir ../apps ../lib  # Adiciona diretórios extras
```

---

## 🔧 Flags Relevantes para Orquestração

### **Subagents (Dynamic Agents)**
```bash
--agents '{
  "debugger": {
    "description": "Debugging specialist for errors",
    "prompt": "You are an expert debugger...",
    "tools": ["Read", "Grep", "Bash"],
    "model": "sonnet"
  }
}'
```

**Campos:**
- `description` (obrigatório): Quando invocar o subagent
- `prompt` (obrigatório): System prompt do subagent
- `tools` (opcional): Tools específicos (senão herda todos)
- `model` (opcional): `sonnet`, `opus`, `haiku`

**💡 Insight para Saci:** Podemos criar subagents dinamicamente para debug mode!

### **Model Selection**
```bash
--model sonnet  # Alias para latest
--model claude-sonnet-4-5-20250929  # Nome completo
--fallback-model sonnet  # Fallback automático se overloaded (print mode only)
```

### **Settings & Configuration**
```bash
--settings ./settings.json  # Carrega settings adicionais
--setting-sources user,project  # Quais sources carregar
```

---

## 💡 Insights para o Saci

### 1. **Print Mode é o que usamos**
```bash
# Saci atualmente faz algo como:
cat prompt.md | claude --dangerously-skip-permissions
```

**Melhorias possíveis:**
```bash
# Adicionar flags úteis:
cat prompt.md | claude \
  --dangerously-skip-permissions \
  --max-turns 10 \
  --output-format json \
  --verbose \
  --append-system-prompt "You are in Saci autonomous loop iteration $i"
```

### 2. **Subagents para Debug Mode**
```bash
# Quando detectar erro de ambiente, podemos:
claude \
  --agents '{
    "environment-fixer": {
      "description": "Fixes environment and configuration errors",
      "prompt": "You are a DevOps expert. Fix missing scripts, wrong configs, etc.",
      "tools": ["Read", "Edit", "Bash"]
    }
  }' \
  -p "Fix the error: npm script db:push missing"
```

### 3. **Structured Output com JSON Schema**
```bash
# Print mode pode retornar JSON validado:
claude -p \
  --json-schema '{"type":"object","properties":{"errorType":{"enum":["ENVIRONMENT","CODE"]}}}' \
  "Classify this error: npm run db:push not found"
```

**💡 Útil para:** Error classification automática!

### 4. **Verbose Mode para Debug**
```bash
# Ver turn-by-turn completo:
claude -p --verbose "query"
```

**💡 Útil para:** Debug do Saci quando loop está falhando

### 5. **Permission Modes**
```bash
--permission-mode plan  # Começa em plan mode
```

**💡 Útil para:** Tasks que precisam de planejamento antes

---

## 🎯 Flags que o Saci Deveria Usar

### **Atualmente:**
```bash
cat prompt.md | claude --dangerously-skip-permissions
```

### **Recomendado:**
```bash
cat prompt.md | claude \
  --dangerously-skip-permissions \
  --max-turns "$MAX_ITERATIONS" \
  --output-format json \
  --verbose \
  --append-system-prompt "Iteration $i of $MAX_ITERATIONS. Previous error: $LAST_ERROR" \
  --session-id "$SESSION_ID" \
  --tools "Read,Write,Edit,Bash,Grep,Glob"
```

**Benefícios:**
- ✅ Max turns explícito (fail-safe)
- ✅ Output estruturado (parsing mais fácil)
- ✅ Verbose para debug
- ✅ Context injection via append-system-prompt
- ✅ Session tracking
- ✅ Tool restriction (segurança)

---

## 🔍 O que NÃO está nesta doc

Precisa buscar em outras docs:
- ❓ **Hooks** (pre/post command execution)
- ❓ **Error handling internals**
- ❓ **Exit codes e error types**
- ❓ **Output format details** (JSON structure)
- ❓ **Streaming event types**

**Próximas docs a buscar:**
1. Settings documentation (hooks provavelmente estão lá)
2. SDK documentation (output format details)
3. Interactive mode (pode ter hooks também)

---

## 📚 Referências

- [Chrome extension](https://code.claude.com/docs/en/chrome) - Browser automation
- [Interactive mode](https://code.claude.com/docs/en/interactive-mode) - Shortcuts
- [Slash commands](https://code.claude.com/docs/en/slash-commands) - Session commands
- [Settings](https://code.claude.com/docs/en/settings) - **⚠️ BUSCAR ESTA (hooks provavelmente aqui)**
- [SDK documentation](https://docs.claude.com/en/docs/agent-sdk) - **⚠️ BUSCAR ESTA (output format)**
