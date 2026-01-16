# Claude Code Hooks Guide - Exemplos Práticos

> Guia prático de como implementar hooks no Claude Code
> Fonte: https://code.claude.com/docs/en/hooks-guide.md

---

## 🎯 Por que este guia é importante

Este documento complementa o [hooks.md](./hooks.md) com **exemplos práticos** de implementação de hooks.

---

## 📋 Exemplo Quickstart: Logging de Comandos Bash

### Passo 1: Usar o comando `/hooks`

```bash
/hooks
```

Selecionar `PreToolUse` hook event.

### Passo 2: Adicionar matcher

Selecionar `+ Add new matcher…` e digitar `Bash` para rodar o hook apenas em comandos Bash.

### Passo 3: Adicionar o hook

```bash
jq -r '"\(.tool_input.command) - \(.tool_input.description // "No description")"' >> ~/.claude/bash-command-log.txt
```

### Passo 4: Salvar

Escolher `User settings` (se logging para home directory).

### Passo 5: Testar

Pedir Claude para rodar `ls` e verificar o log:

```bash
cat ~/.claude/bash-command-log.txt
```

---

## 💡 Exemplos Práticos

### 1. Code Formatting Hook (PostToolUse)

Formata arquivos TypeScript automaticamente após edição:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | { read file_path; if echo \"$file_path\" | grep -q '\\.ts$'; then npx prettier --write \"$file_path\"; fi; }"
          }
        ]
      }
    ]
  }
}
```

### 2. Markdown Formatter Hook

Adiciona language tags automaticamente em code fences:

**Configuração:**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/markdown_formatter.py"
          }
        ]
      }
    ]
  }
}
```

**Script Python (.claude/hooks/markdown_formatter.py):**

```python
#!/usr/bin/env python3
"""
Markdown formatter for Claude Code output.
Fixes missing language tags and spacing issues while preserving code content.
"""
import json
import sys
import re
import os

def detect_language(code):
    """Best-effort language detection from code content."""
    s = code.strip()

    # JSON detection
    if re.search(r'^\s*[{\[]', s):
        try:
            json.loads(s)
            return 'json'
        except:
            pass

    # Python detection
    if re.search(r'^\s*def\s+\w+\s*\(', s, re.M) or \
       re.search(r'^\s*(import|from)\s+\w+', s, re.M):
        return 'python'

    # JavaScript detection
    if re.search(r'\b(function\s+\w+\s*\(|const\s+\w+\s*=)', s) or \
       re.search(r'=>|console\.(log|error)', s):
        return 'javascript'

    # Bash detection
    if re.search(r'^#!.*\b(bash|sh)\b', s, re.M) or \
       re.search(r'\b(if|then|fi|for|in|do|done)\b', s):
        return 'bash'

    # SQL detection
    if re.search(r'\b(SELECT|INSERT|UPDATE|DELETE|CREATE)\s+', s, re.I):
        return 'sql'

    return 'text'

def format_markdown(content):
    """Format markdown content with language detection."""
    # Fix unlabeled code fences
    def add_lang_to_fence(match):
        indent, info, body, closing = match.groups()
        if not info.strip():
            lang = detect_language(body)
            return f"{indent}```{lang}\n{body}{closing}\n"
        return match.group(0)

    fence_pattern = r'(?ms)^([ \t]{0,3})```([^\n]*)\n(.*?)(\n\1```)\s*$'
    content = re.sub(fence_pattern, add_lang_to_fence, content)

    # Fix excessive blank lines (only outside code fences)
    content = re.sub(r'\n{3,}', '\n\n', content)

    return content.rstrip() + '\n'

# Main execution
try:
    input_data = json.load(sys.stdin)
    file_path = input_data.get('tool_input', {}).get('file_path', '')

    if not file_path.endswith(('.md', '.mdx')):
        sys.exit(0)  # Not a markdown file

    if os.path.exists(file_path):
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        formatted = format_markdown(content)

        if formatted != content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(formatted)
            print(f"✓ Fixed markdown formatting in {file_path}")

except Exception as e:
    print(f"Error formatting markdown: {e}", file=sys.stderr)
    sys.exit(1)
```

**Tornar executável:**

```bash
chmod +x .claude/hooks/markdown_formatter.py
```

### 3. Custom Notification Hook

Desktop notifications quando Claude precisa de input:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "notify-send 'Claude Code' 'Awaiting your input'"
          }
        ]
      }
    ]
  }
}
```

### 4. File Protection Hook (PreToolUse)

Bloqueia edições em arquivos sensíveis:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 -c \"import json, sys; data=json.load(sys.stdin); path=data.get('tool_input',{}).get('file_path',''); sys.exit(2 if any(p in path for p in ['.env', 'package-lock.json', '.git/']) else 0)\""
          }
        ]
      }
    ]
  }
}
```

---

## 🚀 Aplicabilidade ao Saci

### Hook para validar comandos Bash (PreToolUse)

**Implementação completa:** Ver [exemplo no GitHub](https://github.com/anthropics/claude-code/blob/main/examples/hooks/bash_command_validator_example.py)

**Conceito:**
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
                "permissionDecisionReason": f"Script doesn't exist. Available: {get_scripts()}"
            }
        }
        print(json.dumps(output))
        sys.exit(0)

sys.exit(0)
```

---

## 📚 Links

- [Hooks Reference](./hooks.md) - Documentação completa
- [CLI Reference](./cli-reference.md) - Flags relacionadas
- [Settings](https://code.claude.com/docs/en/settings) - Configuração
