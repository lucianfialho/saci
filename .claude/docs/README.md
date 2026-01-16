# Claude Code Knowledge Base

Esta pasta contém documentações de referência sobre Claude Code para auxiliar no desenvolvimento do Saci.

## 🎯 Objetivo

Entender recursos e capacidades do Claude Code que podem ser aproveitados pelo Saci:
- **Hooks** (pre/post command execution) - **PRIORIDADE MÁXIMA**
- Error classification e debug mode
- CLI flags úteis para orquestração
- Subagents para contextos separados
- Background tasks para testes longos

## 📁 Estrutura

```
.claude/docs/
├── README.md           (este arquivo)
├── summary.md          (📋 RESUMO - ordem de prioridade para Saci)
│
├── hooks.md            (🔥 CRÍTICO - reference completa)
├── hooks-guide.md      (🔥 CRÍTICO - exemplos práticos)
│
├── cli-reference.md    (🌟 IMPORTANTE - flags úteis)
├── sub-agents.md       (🌟 IMPORTANTE - debug mode)
│
├── interactive-mode.md (⚠️ MÉDIO - background tasks)
├── skills.md           (⚠️ BAIXO - não aplicável ao Saci)
└── checkpointing.md    (❌ NÃO USAR - git rollback é melhor)
```

## 🚀 Quick Start

### Para entender o que implementar:
1. Leia [summary.md](./summary.md) - ordem de prioridade
2. Foque em [hooks.md](./hooks.md) e [hooks-guide.md](./hooks-guide.md)
3. Implemente `.saci/hooks/validate-bash.py`

### Para referência específica:
- **Hooks:** [hooks.md](./hooks.md), [hooks-guide.md](./hooks-guide.md)
- **CLI Flags:** [cli-reference.md](./cli-reference.md)
- **Subagents:** [sub-agents.md](./sub-agents.md)
- **Background tasks:** [interactive-mode.md](./interactive-mode.md)

## 🔥 Prioridade de Implementação

### 1. HOOKS (CRÍTICO) 🌟🌟🌟
**Problema que resolve:**
```
Antes: npm run db:push → erro → rollback → retry → erro (loop infinito)
Depois: Hook bloqueia ANTES → sugere db:migrate → Claude usa correto ✅
```

**Arquivos:** [hooks.md](./hooks.md), [hooks-guide.md](./hooks-guide.md)

### 2. DEBUG MODE (IMPORTANTE) 🌟🌟
**Conceito:**
- Hook detecta erro de ENVIRONMENT
- Saci delega para subagent `environment-fixer`
- Subagent fix + retorna

**Arquivo:** [sub-agents.md](./sub-agents.md)

### 3. CLI IMPROVEMENTS (ÚTIL) 🌟
**Melhorias:**
```bash
--max-turns "$MAX_ITERATIONS"
--output-format json
--verbose
--append-system-prompt "Iteration $i. Error: $LAST_ERROR"
```

**Arquivo:** [cli-reference.md](./cli-reference.md)

## 📚 Status

✅ **Completo** - Knowledge base criado com foco em Hooks e Debug Mode

### Documentos criados:
- ✅ summary.md (overview com prioridades)
- ✅ hooks.md (reference completa)
- ✅ hooks-guide.md (exemplos práticos)
- ✅ cli-reference.md (flags e comandos)
- ✅ sub-agents.md (agentes especializados)
- ✅ interactive-mode.md (background tasks)
- ✅ skills.md (extensões - baixa relevância)
- ✅ checkpointing.md (análise - não usar)

### Não criados (baixa relevância):
- ❌ mcp.md (external tools)
- ❌ headless.md (já usamos `-p`)
- ❌ troubleshooting.md (referência geral)
- ❌ plugins.md (não aplicável)
- ❌ output-styles.md (não aplicável)

## 🎯 Próximo Passo

Implementar sistema de hooks do Saci baseado na documentação:
1. Criar `.saci/hooks/` directory
2. Implementar `validate-bash.py` (PreToolUse)
3. Configurar em `.claude/settings.json`
4. Testar com caso de erro conhecido

---

**Leia [summary.md](./summary.md) para começar!**
