# Sub-agents - Agentes Especializados

> Como criar e usar subagents no Claude Code
> Fonte: https://code.claude.com/docs/en/sub-agents.md

---

## 🎯 O que são Subagents

Subagents são **agentes especializados** que rodam em contexto separado com:
- System prompt customizado
- Tools específicos
- Permissões independentes
- Modelo próprio (Sonnet, Opus, Haiku)

**Quando usar:**
- Preservar contexto principal (exploration separado)
- Enforçar restrições (read-only agents)
- Especializar comportamento (security review, debug)
- Controlar custos (delegar para Haiku)

---

## 🚀 Subagents Built-in

### 1. Explore (Read-only, Haiku)
- **Modelo:** Haiku (rápido, low-latency)
- **Tools:** Read-only (sem Write/Edit)
- **Uso:** File discovery, code search

### 2. Plan (Read-only, inherit model)
- **Modelo:** Herda da conversa principal
- **Tools:** Read-only
- **Uso:** Research para plan mode

### 3. General-purpose (All tools, inherit)
- **Modelo:** Herda
- **Tools:** Todos
- **Uso:** Tasks complexas multi-step

---

## 💡 Relevância para Saci

### **Média-Alta Prioridade**

Subagents podem ser úteis para **debug mode**:

```yaml
# .claude/agents/environment-fixer.md
---
name: environment-fixer
description: Fixes environment and configuration errors
tools: Read, Edit, Bash
model: sonnet
---

You are a DevOps expert. Fix missing scripts, wrong configs, environment issues.

When invoked:
1. Identify the environment error
2. Find the correct solution (check package.json, .env, config files)
3. Implement the fix
4. Verify it works
```

**Como usar no Saci:**

```bash
# Via --agents flag
cat prompt.md | claude \
  --agents '{
    "environment-fixer": {
      "description": "Fixes environment errors like missing npm scripts",
      "prompt": "You are a DevOps expert. Fix environment issues.",
      "tools": ["Read", "Edit", "Bash"],
      "model": "sonnet"
    }
  }' \
  -p "Fix the error: npm script db:push missing"
```

---

## ⚙️ Configuração

### Criar subagent via arquivo:

```markdown
# .claude/agents/debugger.md
---
name: debugger
description: Debug errors and test failures. Use proactively when issues occur.
tools: Read, Edit, Bash, Grep, Glob
model: inherit
---

You are an expert debugger.

Process:
1. Capture error message and stack trace
2. Identify reproduction steps
3. Isolate failure location
4. Implement minimal fix
5. Verify solution works
```

### Criar via CLI flag:

```bash
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer",
    "prompt": "You are a senior code reviewer.",
    "tools": ["Read", "Grep", "Glob"],
    "model": "sonnet"
  }
}'
```

---

## 🔧 Campos de Configuração

| Campo | Descrição |
|-------|-----------|
| `name` | Identificador único |
| `description` | **IMPORTANTE**: Claude usa para decidir quando delegar |
| `tools` | Tools permitidos (allowlist) |
| `disallowedTools` | Tools negados (denylist) |
| `model` | sonnet, opus, haiku, inherit |
| `permissionMode` | default, acceptEdits, dontAsk, bypassPermissions, plan |
| `skills` | Skills para injetar no contexto |
| `hooks` | Hooks específicos do subagent |

---

## 💡 Exemplos Práticos

### 1. Database Query Validator (com hook)

```yaml
---
name: db-reader
description: Execute read-only database queries
tools: Bash
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly-query.sh"
---

You can only run SELECT queries. Cannot modify data.
```

**Script de validação:**

```bash
#!/bin/bash
# ./scripts/validate-readonly-query.sh

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Block write operations
if echo "$COMMAND" | grep -iE '\b(INSERT|UPDATE|DELETE|DROP|CREATE)\b' > /dev/null; then
  echo "Blocked: Write operations not allowed" >&2
  exit 2
fi

exit 0
```

### 2. Code Reviewer (read-only)

```yaml
---
name: code-reviewer
description: Expert code review. Use proactively after code changes.
tools: Read, Grep, Glob, Bash
model: inherit
---

Review checklist:
- Code clarity and readability
- Security issues
- Error handling
- Test coverage
- Performance considerations
```

### 3. Data Scientist (domain-specific)

```yaml
---
name: data-scientist
description: Data analysis expert for SQL and BigQuery. Use for data tasks.
tools: Bash, Read, Write
model: sonnet
---

Specialties:
- Write efficient SQL queries
- Use BigQuery CLI (bq)
- Analyze and summarize results
- Provide data-driven recommendations
```

---

## 🎯 Aplicabilidade ao Saci

### Cenário: Debug Mode

Quando Saci detecta um erro de ENVIRONMENT:

**Via Hooks:**
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": ".saci/hooks/classify-error.py"
      }]
    }]
  }
}
```

**Se erro de ENVIRONMENT → delegar para subagent:**

```bash
# Saci poderia chamar:
cat debug-prompt.md | claude \
  --agents '{
    "env-fixer": {
      "description": "Fix environment errors",
      "prompt": "Fix missing scripts, configs, dependencies",
      "tools": ["Read", "Edit", "Bash"]
    }
  }' \
  -p "Fix error: npm run db:push missing"
```

---

## ⚖️ Subagents vs Outras Opções

| Feature | Contexto | Tools | Quando usar |
|---------|----------|-------|-------------|
| **Subagent** | Separado | Restritos | Isolamento, diferentes tools |
| **Skills** | Mesmo | Mesmos | Adicionar expertise |
| **Hooks** | N/A | N/A | Validação automática |
| **System prompt** | Mesmo | Mesmos | Instruções gerais |

---

## 🔍 Foreground vs Background

### Foreground (blocking):
- Bloqueia conversa principal
- Permission prompts passados para usuário
- Pode fazer perguntas via `AskUserQuestion`

### Background (concurrent):
- Roda em paralelo
- Herda permissions, auto-deny o resto
- Sem MCP tools
- Sem perguntas interativas

**Controlar:**
- Claude decide baseado na task
- Usuário pode pedir "run in background"
- `Ctrl+B` para backgroundear task rodando

---

## 📚 Links

- [Hooks](./hooks.md) - Event handlers
- [Skills](./skills.md) - Model-invoked expertise
- [Plugins](https://code.claude.com/docs/en/plugins) - Distribuir subagents
