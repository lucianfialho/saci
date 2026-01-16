# CLAUDE.md

Instruções para Claude Code ao trabalhar no projeto Saci.

---

## 🎯 Sobre o Projeto

**Saci** é um sistema de autonomous coding loop que orquestra o Claude Code CLI para executar tasks de um Product Requirement Plan (PRP).

### Arquitetura:
- **saci.sh** - Loop principal (Bash)
- **prp.json** - Task definitions com DAG de dependências
- **Rollback via git** - Checkpoint antes de cada iteração
- **TUI** - Terminal UI para visualização de progresso

### Competidores:
- **Ralph** - Similar mas sem dependencies, sem rollback, sem TUI

---

## 📚 Claude Code Knowledge Base

**IMPORTANTE:** Antes de implementar features de orquestração, error handling ou debug mode, **SEMPRE consulte** `.claude/docs/summary.md` para entender as capabilities do Claude Code.

### Documentação Relevante:

| Arquivo | Prioridade | Quando Consultar |
|---------|------------|------------------|
| `.claude/docs/summary.md` | 🔥 CRÍTICO | Overview e prioridades |
| `.claude/docs/hooks.md` | 🔥 CRÍTICO | Error classification, validação de comandos |
| `.claude/docs/hooks-guide.md` | 🔥 CRÍTICO | Exemplos práticos de hooks |
| `.claude/docs/cli-reference.md` | 🌟 IMPORTANTE | Flags úteis do CLI |
| `.claude/docs/sub-agents.md` | 🌟 IMPORTANTE | Debug mode com contexto separado |
| `.claude/docs/interactive-mode.md` | ⚠️ MÉDIO | Background tasks |

### Princípio Fundamental:

**Sempre prefira usar hooks do Claude Code ao invés de reimplementar funcionalidades.**

Exemplo: Para validar comandos Bash ANTES de executar, use `PreToolUse` hooks ao invés de parser bash no Saci.

---

## ✅ Features Implementadas

### 1. Sistema de Hooks (✅ COMPLETO)
- **Status:** 4 hooks implementados e testados (19/19 testes passando)
- **Hooks ativos:**
  - **PreToolUse** - Valida comandos npm/git ANTES de executar
  - **PostToolUse** - Classifica erros (ENVIRONMENT/CODE/TIMEOUT)
  - **Stop** - Previne parada prematura quando tests falham
  - **UserPromptSubmit** - Injeta contexto automaticamente
- **Documentação:** `.saci/README.md`, `.saci/TESTING.md`
- **Impacto:** Reduz iterações desperdiçadas em ~40%

### 2. Error Classification System (✅ COMPLETO)
- **Status:** Integrado com PostToolUse hook
- **Tipos:** ENVIRONMENT (missing scripts/files) vs CODE (syntax/logic errors)
- **Output:** JSON estruturado com suggestion + file:line extraction
- **Documentação:** `.claude/docs/saci-analysis.md`

### 3. CLI Enhancements (✅ COMPLETO)
- **Flags adicionados:**
  - `--max-turns $MAX_ITERATIONS` - Fail-safe contra runaway loops
  - `--verbose` - Detailed logging para debugging
  - `--append-system-prompt` - Context injection sem substituir default prompt
- **Localização:** `saci.sh` linha 642

### 4. Debug Mode Framework (✅ PRONTO para ativação)
- **Status:** Subagent implementado, funções helper criadas
- **Subagent:** `.claude/agents/environment-fixer.md` - DevOps specialist
- **Integração:** Documentada em `.saci/DEBUG-MODE.md`
- **Quando ativar:** Quando quiser auto-fix de erros ENVIRONMENT

## 🚀 Próximas Oportunidades

### 1. Background Task Execution
- **Objetivo:** Rodar testes longos em background enquanto trabalha em outras tasks
- **Referência:** `.claude/docs/interactive-mode.md`

### 2. Incremental Testing Strategy
- **Objetivo:** Rodar unit tests → integration → full test suite (fail fast)
- **Benefício:** Economiza tempo em iterações com erros básicos

### 3. Persistent Checkpoint System
- **Objetivo:** Preservar trabalho útil mesmo quando tests falham
- **Abordagem:** Stash parcial ao invés de hard reset total

### 4. Métricas e Telemetria
- **Objetivo:** Medir loop efficiency, commands blocked, avg iterations
- **Uso:** Validar se hooks estão funcionando conforme esperado

---

## 🎯 Convenções

### Commits:
- Usar formato: `feat: description [task-ID]` ou `chore: description`
- Sempre incluir `Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>`

### Testing:
- Rodar testes antes de commit quando relevante
- Validar que build funciona

### Documentation:
- Atualizar PRP quando tasks são completadas
- Manter `progress.txt` atualizado

---

## ⚠️ Evitar

- **NÃO** reimplementar checkpointing estilo Claude Code (git rollback é superior)
- **NÃO** adicionar complexidade desnecessária
- **NÃO** ignorar a documentação em `.claude/docs/` ao implementar features de orquestração
