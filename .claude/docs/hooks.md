# Claude Code Hooks - CRITICAL for Saci 🔥

> **Esta é a doc MAIS IMPORTANTE!** Hooks podem resolver o problema de error classification e debug mode.
> Fonte: https://code.claude.com/docs/en/hooks.md

---

## 🎯 Por que Hooks são Relevantes para o Saci

Hooks do Claude Code permitem **interceptar eventos** e **tomar ações** automaticamente. Isso resolve exatamente o problema que discutimos:

### **Problema Atual do Saci:**
```
Erro: "npm run db:push" não existe
Saci: Rollback → Tenta de novo
Claude: Mesma coisa... "npm run db:push"
Erro: Mesma coisa... ← LOOP INFINITO
```

### **Solução com Hooks:**
```
Claude tenta rodar: "npm run db:push"
Hook PreToolUse: Intercepta comando bash
Hook valida: "db:push não existe, sugerir db:migrate"
Hook retorna: Exit code 2 → BLOQUEIA comando
Claude recebe feedback: "Use npm run db:migrate instead"
Claude usa comando correto ✅
```

---

## 📋 Hook Events Disponíveis

### **PreToolUse** 🌟🌟🌟
**Quando:** Antes de Claude executar qualquer tool
**Use case:** Validar comandos ANTES de rodar, classificar erros

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/validate-bash.py"
          }
        ]
      }
    ]
  }
}
```

**Input (stdin JSON):**
```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "npm run db:push",
    "description": "Run database migration"
  },
  "session_id": "abc123",
  "cwd": "/project/path"
}
```

**Output (exit codes):**
- `0`: Allow tool (stdout ignored, unless JSON)
- `2`: **BLOCK tool** (stderr shown to Claude!)
- `outros`: Non-blocking error

**Output (JSON):** ← PODER!
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Command 'npm run db:push' does not exist. Use 'npm run db:migrate' instead."
  }
}
```

### **PostToolUse** 🌟🌟
**Quando:** Imediatamente após tool completar com sucesso
**Use case:** Validar resultados, detectar erros de teste

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/check-test-output.py"
          }
        ]
      }
    ]
  }
}
```

**Output com feedback:**
```json
{
  "decision": "block",
  "reason": "Tests failed: TypeError on line 42. The error indicates you're calling .map() on undefined. Check the variable initialization.",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Stack trace shows issue in file.ts:42"
  }
}
```

### **UserPromptSubmit** 🌟
**Quando:** Usuário submit prompt, ANTES de Claude processar
**Use case:** Adicionar contexto automático (git status, env info)

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/add-context.sh"
          }
        ]
      }
    ]
  }
}
```

**Output (stdout é adicionado ao contexto!):**
```
Current branch: feature/auth
Uncommitted changes: 3 files
Last error: npm ERR! missing script: db:push
Available npm scripts: db:migrate, db:generate, typecheck
```

### **Stop** 🌟
**Quando:** Claude quer parar de trabalhar
**Use case:** Forçar Claude a continuar se há erros não resolvidos

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/check-if-done.py"
          }
        ]
      }
    ]
  }
}
```

**Output (bloqueia stoppage):**
```json
{
  "decision": "block",
  "reason": "Tests are still failing. You must fix the TypeErrors before stopping."
}
```

### **SessionStart** 🌟
**Quando:** Claude Code inicia sessão
**Use case:** Carregar env vars, setup inicial

Matchers:
- `startup`: Nova sessão
- `resume`: Resumindo sessão
- `clear`: Após /clear
- `compact`: Após compact

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/setup-env.sh"
          }
        ]
      }
    ]
  }
}
```

**Special:** Pode persistir env vars!
```bash
#!/bin/bash
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export NODE_ENV=production' >> "$CLAUDE_ENV_FILE"
  echo 'export PATH="$PATH:./node_modules/.bin"' >> "$CLAUDE_ENV_FILE"
fi
```

### Outros Events

| Event | Quando | Relevância Saci |
|-------|--------|-----------------|
| **PermissionRequest** | Dialog de permissão | ⚠️ Média (Saci usa --dangerously-skip-permissions) |
| **Notification** | Claude Code envia notificação | ⚠️ Baixa |
| **SubagentStop** | Subagent quer parar | ⚠️ Baixa (Saci não usa subagents) |
| **PreCompact** | Antes de compact | ⚠️ Baixa |
| **SessionEnd** | Sessão termina | ⚠️ Baixa |

---

## 💡 Aplicações para o Saci

### 1. **Error Classification** (PreToolUse)
```python
#!/usr/bin/env python3
import json, sys, re

input_data = json.load(sys.stdin)
command = input_data.get("tool_input", {}).get("command", "")

# Detectar erro de ENVIRONMENT
if re.search(r"npm run \w+", command):
    # Verificar se script existe em package.json
    if not script_exists(command):
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": f"Script doesn't exist. Available scripts: {get_available_scripts()}"
            }
        }
        print(json.dumps(output))
        sys.exit(0)

# Allow comando
sys.exit(0)
```

### 2. **Auto Context Injection** (UserPromptSubmit)
```bash
#!/bin/bash
# Adicionar contexto automático em cada prompt

echo "## Environment Context"
echo "- Branch: $(git branch --show-current)"
echo "- Uncommitted changes: $(git status --short | wc -l)"
echo "- Last npm error: $(tail -1 ~/.npm/_logs/*.log 2>/dev/null | grep 'npm ERR!' | head -1)"
echo ""
echo "## Available Commands"
npm run | grep "^  " | head -5
```

### 3. **Test Failure Detection** (PostToolUse)
```python
#!/usr/bin/env python3
import json, sys

input_data = json.load(sys.stdin)
tool_response = input_data.get("tool_response", {})
output_text = str(tool_response)

# Detectar falhas de teste
if "npm ERR!" in output_text or "FAIL" in output_text:
    # Extrair erro específico
    error_line = extract_error(output_text)

    output = {
        "decision": "block",
        "reason": f"Test command failed: {error_line}. You must fix this before proceeding.",
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": "This is a test failure, not an environment issue. Debug the code."
        }
    }
    print(json.dumps(output))
    sys.exit(0)
```

### 4. **Prevent Premature Stop** (Stop)
```python
#!/usr/bin/env python3
import json, sys, subprocess

# Verificar se há erros não resolvidos
result = subprocess.run(["npm", "run", "typecheck"], capture_output=True)

if result.returncode != 0:
    output = {
        "decision": "block",
        "reason": "Typecheck is still failing. You cannot stop until all errors are fixed."
    }
    print(json.dumps(output))
    sys.exit(0)

# Allow stop
sys.exit(0)
```

---

## 🔧 Configuração para Saci

### Onde configurar:
- `~/.claude/settings.json` (global)
- `.claude/settings.json` (por projeto)
- `.claude/settings.local.json` (gitignored)

### Exemplo completo:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.saci/hooks/validate-bash.py",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.saci/hooks/check-test-output.py",
            "timeout": 10
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.saci/hooks/add-context.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.saci/hooks/check-if-done.py",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

---

## 🚀 Próximos Passos para o Saci

1. **Criar `.saci/hooks/` directory** com scripts de validação
2. **Implementar error classifier** em PreToolUse
3. **Adicionar auto-context** em UserPromptSubmit
4. **Test failure detector** em PostToolUse
5. **Prevent premature stop** em Stop hook

**Resultado:** Saci se torna MUITO mais inteligente na detecção e recovery de erros! 🎉

---

## ⚠️ Limitações

1. **Hooks só funcionam com Claude Code CLI** (não com API direta)
2. **Timeout padrão:** 60 segundos
3. **Parallel execution:** Todos hooks matching rodam em paralelo
4. **Exit code 2 comportamento:**
   - PreToolUse: Bloqueia tool
   - PostToolUse: Tool já rodou, só feedback
   - UserPromptSubmit: Bloqueia prompt
   - Stop: Bloqueia stoppage

---

## 📚 Links Relacionados

- [Hooks Guide](https://code.claude.com/docs/en/hooks-guide) - Exemplos práticos
- [CLI Reference](./cli-reference.md) - Flags relacionadas
- [Settings](https://code.claude.com/docs/en/settings) - Configuração
