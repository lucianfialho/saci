# Agent Skills - Extensões para Claude Code

> Como criar Skills para ensinar Claude a fazer tarefas específicas
> Fonte: https://code.claude.com/docs/en/skills.md

---

## 🎯 O que são Skills

Skills são **arquivos markdown** que ensinam Claude a fazer algo específico. Diferente de slash commands, Skills são **invocadas automaticamente** por Claude quando a tarefa match com a description.

### Exemplo:

```yaml
---
name: explaining-code
description: Explains code with visual diagrams and analogies. Use when explaining how code works.
---

When explaining code, always include:
1. **Analogy**: Compare to everyday life
2. **ASCII diagram**: Show flow/structure
3. **Step-by-step walkthrough**
4. **Common gotcha**
```

---

## 💡 Relevância para Saci

### **Baixa Prioridade**

Skills são úteis para:
- Ensinar Claude padrões específicos do projeto
- Automatizar tarefas repetitivas (code review, commits)
- Adicionar expertise específica (SQL, security)

**MAS:**
- Saci roda em modo não-interativo (-p flag)
- Skills são mais úteis em conversas interativas
- Saci precisa de **hooks** (validação de comandos), não skills

---

## 🔍 Skills vs Outras Features

| Feature | Quando roda | Use case |
|---------|-------------|----------|
| **Skills** | Claude decide automaticamente | Expertise específica, padrões |
| **Slash commands** | Usuário digita `/command` | Prompts reutilizáveis |
| **Hooks** | Eventos (PreToolUse, PostToolUse) | Validação, linting automático |
| **Subagents** | Claude delega tarefas | Contexto separado, diferentes tools |

**Para Saci:** Hooks > Subagents > Skills > Slash commands

---

## 📁 Estrutura de Skills

### Localização:

| Tipo | Caminho | Escopo |
|------|---------|--------|
| Personal | `~/.claude/skills/` | Todos os projetos |
| Project | `.claude/skills/` | Time (version control) |
| Plugin | Bundled com plugin | Quem instalar plugin |

### Arquivos:

```
my-skill/
├── SKILL.md (obrigatório - overview)
├── reference.md (detalhes técnicos - carregado quando necessário)
├── examples.md (exemplos - carregado quando necessário)
└── scripts/
    └── helper.py (executado, NÃO carregado no contexto)
```

---

## ⚙️ Configuração

### Frontmatter básico:

```yaml
---
name: skill-name
description: When to use this skill (Claude uses this to decide!)
---
```

### Campos opcionais:

| Campo | Descrição |
|-------|-----------|
| `allowed-tools` | Tools que pode usar sem pedir permissão |
| `model` | Modelo específico (sonnet, opus, haiku) |
| `context: fork` | Roda em contexto separado (subagent) |
| `agent` | Tipo de agent (quando context: fork) |
| `hooks` | Hooks específicos do Skill |
| `user-invocable` | Se aparece no menu de slash commands |

---

## 🚀 Exemplo Prático

### Code Review Skill:

```yaml
---
name: code-reviewer
description: Reviews code for quality and best practices. Use when reviewing PRs or after changes.
allowed-tools: Read, Grep, Glob, Bash
---

# Code Review Process

1. Run `git diff --staged` to see changes
2. Focus on modified files
3. Check for:
   - Security issues (exposed secrets, SQL injection)
   - Performance problems
   - Code duplication
   - Error handling

Provide feedback organized by priority:
- **Critical** (must fix)
- **Warning** (should fix)
- **Suggestion** (consider)
```

---

## 🔗 Skills e Subagents

### Dar Skills a um subagent:

```yaml
# .claude/agents/code-reviewer.md
---
name: code-reviewer
description: Review code for quality
skills: pr-review, security-check
---
```

**IMPORTANTE:** Skills são **injetadas no contexto** do subagent, não apenas disponibilizadas.

---

## ⚠️ Quando NÃO usar Skills

Para Saci, **evitar Skills** e focar em:

1. **Hooks** - Validação automática de comandos
2. **System prompts** - Via `--append-system-prompt`
3. **Subagents** - Para debug mode (contexto separado)

Skills são mais úteis para:
- Projetos interativos (não headless)
- Padrões de código específicos do time
- Expertise de domínio (SQL, security, etc)

---

## 📚 Links

- [Hooks Guide](./hooks-guide.md) - Implementação prática
- [Sub-agents](./sub-agents.md) - Contextos separados
- [Best Practices](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices) - Guia oficial
