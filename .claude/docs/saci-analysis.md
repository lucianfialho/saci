# Saci - Análise Completa do Sistema

> Análise detalhada de todas as funcionalidades, fluxos, pain points e oportunidades de melhoria

**Data:** 2026-01-16
**Versão:** 1.0.0
**Baseado em:** saci.sh (680 lines), lib/, tests/

---

## 📋 Índice

1. [Overview do Sistema](#1-overview-do-sistema)
2. [Análise de Funcionalidades](#2-análise-de-funcionalidades)
3. [Pain Points Identificados](#3-pain-points-identificados)
4. [Oportunidades de Melhoria](#4-oportunidades-de-melhoria)
5. [Comparação com Competidores](#5-comparação-com-competidores)
6. [Métricas e KPIs](#6-métricas-e-kpis)

---

## 1. Overview do Sistema

### 1.1 Arquitetura Geral

```
saci/
├── saci.sh                  # Core: autonomous loop orchestrator
├── lib/
│   ├── generator.sh         # PRP generation wizard
│   ├── tui.sh              # Terminal UI for visualization
│   └── utils.sh            # Shared utilities
├── tests/
│   └── integration/        # 6 integration tests
├── prp.json                # Task definitions (generated)
└── progress.txt            # Execution log (generated)
```

**Componentes principais:**
- **saci.sh** (680 lines): Orquestrador principal, loop autônomo
- **PRP System**: Gerenciamento de tasks com DAG de dependencies
- **TUI**: Visualização real-time do progresso
- **Generator**: Criação interativa de tasks
- **Git Integration**: Rollback automático em failures

### 1.2 Fluxo de Execução End-to-End

```mermaid
graph TD
    A[Start: saci] --> B[Parse Args]
    B --> C[Load PRP]
    C --> D[Validate Dependencies]
    D --> E{Has Tasks?}
    E -->|No| Z[Done]
    E -->|Yes| F[get_next_task]
    F --> G[execute_task_with_retries]
    G --> H[RETRY LOOP: 1..MAX_ITERATIONS]
    H --> I[run_single_iteration]
    I --> J[Git Checkpoint]
    J --> K[Build Prompt]
    K --> L[Spawn Claude Session]
    L --> M{Files Changed?}
    M -->|No| N[Skip/Retry]
    M -->|Yes| O[Run Tests]
    O --> P{Tests Pass?}
    P -->|Yes| Q[Commit + Mark Complete]
    P -->|No| R[Git Rollback]
    R --> S{Max Iterations?}
    S -->|No| H
    S -->|Yes| T[Skip Task]
    Q --> E
    T --> E
```

**Resumo:**
1. Carrega PRP e valida dependencies (circular detection)
2. Loop principal: seleciona próxima task (topological sort)
3. Loop de retry: até MAX_ITERATIONS (default: 10)
4. Cada iteração: checkpoint git → Claude session → test → commit ou rollback
5. Context window **fresh** em cada iteração (não cumulativo)
6. Error context passado via LAST_ERROR variable

---

## 2. Análise de Funcionalidades

### 2.1 Sistema de PRP (Product Requirement Plan)

#### Estrutura do prp.json

```json
{
  "project": {
    "name": "Project Name",
    "description": "Description",
    "branchName": "feature/branch-name"
  },
  "features": [
    {
      "id": "F1",
      "name": "Feature Name",
      "description": "Feature description",
      "priority": 1,
      "tasks": [
        {
          "id": "F1-T1",
          "title": "Task title",
          "description": "Detailed description",
          "priority": 1,
          "passes": false,
          "dependencies": ["F1-T0"],
          "dependencyMode": "all",
          "context": {
            "files": ["src/file.ts"],
            "libraries": ["library"],
            "hints": ["Hint text"]
          },
          "acceptance": [
            "Acceptance criterion 1",
            "Acceptance criterion 2"
          ],
          "tests": {
            "command": "npm test"
          }
        }
      ]
    }
  ]
}
```

**Campos obrigatórios:**
- `id`, `title`, `description`, `priority`, `passes`

**Campos opcionais:**
- `dependencies`, `dependencyMode`, `context`, `acceptance`, `tests`

**Backward compatibility:**
- Todos os campos de dependency são opcionais
- Defaults: `dependencies: []`, `dependencyMode: "all"`

#### Dependency Modes

**Mode: "all" (default)**
```
Task só executa se TODAS as dependencies tiverem passes: true
```

**Mode: "any"**
```
Task executa se PELO MENOS UMA dependency tiver passes: true
```

**Implementação (saci.sh:214-297):**
```bash
check_dependencies_met() {
    local task_id="$1"
    local deps=$(get_task_dependencies "$task_id")
    local mode=$(get_dependency_mode "$task_id")

    if [ "$mode" = "any" ]; then
        # Precisa de pelo menos 1 completa
        [ $completed_count -gt 0 ]
    else
        # Precisa de todas completas
        [ $completed_count -eq $total_count ]
    fi
}
```

#### Task States

```
┌─────────────┐
│   PENDING   │  passes: false, dependencies not met
│    (⊗)      │
└─────┬───────┘
      │ dependencies satisfied
      ▼
┌─────────────┐
│    READY    │  passes: false, dependencies met
│    (□)      │
└─────┬───────┘
      │ selected by get_next_task()
      ▼
┌─────────────┐
│   RUNNING   │  Currently executing (marked in loop)
│    (▶)      │
└─────┬───────┘
      │ tests pass
      ▼
┌─────────────┐
│  COMPLETED  │  passes: true
│    (■)      │
└─────────────┘
```

**Nota:** Não há estados explícitos de "in_progress" ou "failed" - tracking via:
- Iteration counter (em prompt context)
- Git checkpoints (para rollback)
- progress.txt (historical context)

#### Circular Dependency Detection

**Algorithm: Depth-First Search (DFS)**

```bash
detect_circular_dependency() {
    local task_id="$1"
    local path="${2:-}"
    local visited="${3:-}"

    # Check if already in current path (cycle detected!)
    if echo "$path" | grep -q "$task_id"; then
        echo "$path -> $task_id"
        return 1
    fi

    # Mark as visited
    visited="$visited $task_id"
    path="$path -> $task_id"

    # Recursively check dependencies
    for dep in $dependencies; do
        if ! detect_circular_dependency "$dep" "$path" "$visited"; then
            return 1  # Cycle found
        fi
    done

    return 0  # No cycle
}
```

**Validação:**
- Executada no startup (main:759)
- Bloqueia execução se ciclo detectado
- Mostra caminho completo do ciclo

**Exemplo de erro:**
```
ERROR: Circular dependency detected: F1-T1 -> F1-T2 -> F1-T3 -> F1-T1
```

#### Task Selection Algorithm

**Função:** `get_next_task()` (saci.sh:124-152)

```bash
get_next_task() {
    # 1. Get all incomplete tasks (passes: false)
    # 2. Sort by priority (ascending: 1, 2, 3...)
    # 3. For each candidate:
    #    - Check if dependencies met
    #    - Return first task that passes check
    # 4. Return empty if no candidates
}
```

**Implementação:**
- Topological sort implícito (via dependency check)
- Priority-based selection (lower number = higher priority)
- First-fit strategy (retorna primeiro match)

**Edge case:** Se duas tasks têm mesma priority e dependencies satisfeitas, ordem é **não-determinística** (baseada em order no JSON).

#### Cascade Reset

**Comando:** `saci reset F1-T1 --cascade`

**Comportamento:**
1. Reset task especificada: `passes: false`
2. Encontra todas as tasks que dependem dela
3. Recursivamente reset dependents (transitive closure)
4. Previne infinite loops (visited tracking)

**Uso:**
```bash
# Reset apenas uma task
saci reset F1-T1

# Reset task + todas que dependem dela
saci reset F1-T1 --cascade

# Reset todas as tasks
saci reset
```

### 2.2 Loop Autônomo

#### Main Loop Structure

**Localização:** saci.sh:702-833

```bash
main() {
    # 1. Parse arguments
    # 2. Validate PRP
    # 3. Detect circular dependencies
    # 4. Initialize progress file

    # MAIN LOOP
    while true; do
        next_task=$(get_next_task)
        [ -z "$next_task" ] && break

        if execute_task_with_retries "$next_task"; then
            # Task completed
            continue
        else
            # Task failed after MAX_ITERATIONS
            log_error "Task $next_task failed, skipping..."
            # Move to next task
        fi
    done
}
```

#### Retry Mechanism

**Função:** `execute_task_with_retries()` (saci.sh:660-696)

```bash
execute_task_with_retries() {
    local task_id="$1"
    local iteration=1
    local LAST_ERROR=""

    while [ $iteration -le $MAX_ITERATIONS ]; do
        log_iteration "━━━ Iteration $iteration of $MAX_ITERATIONS ━━━"

        if run_single_iteration "$task_id" "$iteration" "$LAST_ERROR"; then
            log_success "Task completed on iteration $iteration!"
            return 0
        fi

        # Capture error for next iteration
        LAST_ERROR="$(cat "$test_output_file" | tail -50)"

        iteration=$((iteration + 1))
        [ $iteration -le $MAX_ITERATIONS ] && sleep 2
    done

    log_error "Task failed after $MAX_ITERATIONS iterations"
    return 1
}
```

**Características:**
- **Fresh context** em cada iteração (nova sessão Claude)
- Error context propagado via `$LAST_ERROR`
- Sleep de 2s entre iterações
- Return codes: 0 (success), 1 (failure)

#### Single Iteration Flow

**Função:** `run_single_iteration()` (saci.sh:489-657)

```bash
run_single_iteration() {
    local task_id="$1"
    local iteration="$2"
    local previous_error="$3"

    # 1. Git checkpoint
    git_checkpoint=$(git rev-parse HEAD)

    # 2. Build prompt (com previous_error)
    build_task_prompt "$task_id" "$iteration" "$previous_error"

    # 3. Spawn Claude session
    cat "$prompt_file" | $cli_cmd 2>&1 | tee "$cli_output_file"

    # 4. Check file changes
    changed_files=$(git status --porcelain | wc -l)
    if [ "$changed_files" -eq 0 ]; then
        # No changes made
        return 1
    fi

    # 5. Run tests
    if eval "$test_cmd" 2>&1 | tee "$test_output_file"; then
        # Tests passed!
        git add -A
        git commit -m "feat: $title [task-$task_id]"
        mark_task_complete "$task_id"
        return 0
    else
        # Tests failed - rollback
        git reset --hard "$git_checkpoint"
        git clean -fd -e prp.json -e progress.txt
        return 1
    fi
}
```

#### Fresh Context Window Strategy

**Por que fresh context?**
- Evita context window overflow (>200k tokens)
- Força Claude a re-pensar problema (não acumular bad assumptions)
- Permite different approaches em cada iteration

**Trade-off:**
- ✅ PRO: Abordagens diversas, menos overfitting
- ❌ CON: Claude pode esquecer learnings da iteração anterior

**Mitigação:** progress.txt com last 100 lines injetado no prompt

### 2.3 Error Handling Atual

#### Three-Level Validation

**Level 1: File Modification Check** (saci.sh:556-570)
```bash
# Verifica se algum arquivo foi modificado
changed_files=$(git status --porcelain | wc -l)

if [ "$changed_files" -eq 0 ]; then
    # Se task já está marked complete, aceitar
    task_status=$(jq -r '.features[].tasks[] | select(.id == $id) | .passes')
    [ "$task_status" = "true" ] && return 0

    # Senão, falha (Claude não fez nada)
    LAST_ERROR="No files were modified..."
    return 1
fi
```

**Level 2: Test Execution** (saci.sh:574-639)
```bash
# Roda test command e captura output
if eval "$test_cmd" 2>&1 | tee "$test_output_file"; then
    # Success path
    git add -A
    git commit -m "feat: $title [task-$task_id]"
    mark_task_complete "$task_id"
    return 0
else
    # Failure path
    LAST_ERROR="$(cat "$test_output_file" | tail -50)"
    git reset --hard "$git_checkpoint"
    git clean -fd -e prp.json -e progress.txt
    return 1
fi
```

**Level 3: Session Health Check** (saci.sh:550-552)
```bash
# Verifica se Claude CLI executou com sucesso
if cat "$prompt_file" | $cli_cmd 2>&1 | tee "$cli_output_file"; then
    # Session OK
else
    # Session crashed - rollback e retry
    git reset --hard "$git_checkpoint"
    return 1
fi
```

#### Git Checkpoint/Rollback

**Checkpoint (antes de executar):**
```bash
git_checkpoint=$(git rev-parse HEAD 2>/dev/null || echo "")
```

**Rollback (em caso de falha):**
```bash
if [ -n "$git_checkpoint" ]; then
    log_info "Rolling back to checkpoint ${git_checkpoint:0:7}..."
    git reset --hard "$git_checkpoint" 2>/dev/null || true
    git clean -fd -e prp.json -e progress.txt 2>/dev/null || true
    log_success "Rollback complete"
fi
```

**Files preservados durante rollback:**
- `prp.json` - task states
- `progress.txt` - historical context

**Files removidos:**
- Tudo que não está committed
- Arquivos untracked (exceto prp.json e progress.txt)

#### Error Storage em progress.txt

**Estrutura:**
```
# Progress reset at [TIMESTAMP]

## [TIMESTAMP] Task F1-T1
- Started iteration 1
- Claude tried approach X
- Tests failed: Error Y
- Learning: Z doesn't work

## [TIMESTAMP] Task F1-T1 (iteration 2)
- Trying different approach...
- Error: Still failing
- Pattern: Same error type

## [TIMESTAMP] Task F1-T1 (iteration 3)
- Success! Approach Q worked
```

**Context Injection:**
```bash
# Last 100 lines are injected in prompt
tail -100 progress.txt
```

**Risk:** Unbounded growth - progress.txt pode ficar enorme em execuções longas.

#### Limitação CRÍTICA: Sem Classificação de Erros

**Problema:**
Todos os erros são tratados identicamente. Não há distinção entre:

- **ENVIRONMENT errors**: npm script missing, file not found, dependency issue
- **CODE errors**: syntax error, type error, logic bug, test failure
- **TIMEOUT errors**: hanging process, infinite loop
- **FLAKY errors**: intermittent test failures

**Impacto:**
- Loop infinito em ENVIRONMENT errors (Claude tentando npm script que não existe)
- Desperdício de iterações (same mistake repeated)
- Sem estratégia de recovery específica por tipo de erro

**Exemplo real:**
```
Iteration 1: npm run db:push → erro (script não existe)
Iteration 2: npm run db:push → erro (MESMO ERRO)
Iteration 3: npm run db:push → erro (LOOP INFINITO)
...
```

### 2.4 CLI Integration

#### Current Implementation

**Localização:** saci.sh:536-550

```bash
# Provider selection
case "$CLI_PROVIDER" in
    claude)
        cli_cmd="claude --print --dangerously-skip-permissions"
        ;;
    amp)
        cli_cmd="amp --print --dangerously-skip-permissions"
        ;;
esac

# Execute
if cat "$prompt_file" | $cli_cmd 2>&1 | tee "$cli_output_file"; then
    # Success
else
    # Failure - rollback
fi
```

**Flags utilizados:**
- `--print`: Non-interactive mode (print-only, no REPL)
- `--dangerously-skip-permissions`: Auto-approve all file operations

**Comunicação:**
- **Input:** Prompt via stdin (cat "$prompt_file")
- **Output:** stdout/stderr captured em "$cli_output_file"

#### Oportunidades: Flags Não Utilizados

Baseado em `.claude/docs/cli-reference.md`, flags úteis:

**1. `--max-turns N`**
```bash
claude --print --max-turns 10
```
- Limita turns da sessão Claude (fail-safe adicional)
- Complementa MAX_ITERATIONS do Saci
- Previne Claude de rodar indefinidamente

**2. `--output-format json`**
```bash
claude --print --output-format json
```
- Retorna JSON estruturado com result, session_id, metadata
- Facilita parsing de outputs
- Permite extrair métricas (tokens used, model, etc)

**3. `--verbose`**
```bash
claude --print --verbose
```
- Log turn-by-turn completo
- Útil para debug de sessões que falharam
- Mostra tool calls e resultados

**4. `--append-system-prompt`**
```bash
claude --print --append-system-prompt "Iteration $i/$MAX. Previous error: $ERROR_TYPE"
```
- Adiciona instruções SEM substituir prompt default
- Context injection (iteration number, error type)
- Mantém capabilities do Claude Code

**5. `--json-schema`**
```bash
claude --print --json-schema '{"type":"object","properties":{"success":{"type":"boolean"}}}'
```
- Structured output conforme schema
- Útil para extração de metadata (success, error_type, etc)

**ROI:** Médio-Alto - Baixo esforço, melhoria significativa em debugging e controle.

### 2.5 Progress Tracking

#### progress.txt Structure

**Formato:**
```
# Progress reset at [TIMESTAMP]

## [TIMESTAMP] Task F1-T1: Task Title
### Iteration 1
- Attempt: Tried approach X
- Result: Failed with error Y
- Learning: Discovered Z doesn't work

### Iteration 2
- Attempt: Different approach Q
- Result: Still failing
- Pattern: Same error type (TYPE_ERROR)

### Iteration 3
- Attempt: Fixed root cause
- Result: Success! Tests passing
- Committed: abc123f

─────────────────────────────────────────

## [TIMESTAMP] Task F1-T2: Next Task
...
```

#### Context Injection (Last 100 Lines)

**Implementação:** (saci.sh:407)
```bash
# Read last 100 lines of progress
if [ -f "$PROGRESS_FILE" ]; then
    progress_context=$(tail -100 "$PROGRESS_FILE")
fi

# Inject in prompt
cat > "$prompt_file" <<EOF
...
## Progress Context (Last 100 Lines)
$progress_context
EOF
```

**Benefício:**
- Claude vê historical context de tentativas anteriores
- Aprende com erros passados
- Evita repeat mistakes (em teoria)

**Limitação:**
- Apenas last 100 lines (pode truncar contexto importante)
- Se task tem >100 lines de progress, perde início
- Não há summarization automática

#### Risk: Unbounded Growth

**Problema:**
progress.txt cresce indefinidamente:
- Cada task adiciona N iterations × M lines
- Long-running projects podem ter 10k+ lines
- I/O overhead para ler/escrever file grande

**Mitigação possível:**
- Rotate progress.txt após N tasks
- Arquivar historical progress
- Summarize old progress periodically

### 2.6 TUI (Terminal UI)

#### Real-time Visualization

**Localização:** lib/tui.sh

**Componentes:**
```
┌─────────────────────────────────────────┐
│ 🎯 Saci - Autonomous Coding Loop       │
├─────────────────────────────────────────┤
│ Feature F1: Authentication              │
│  ▶ F1-T1: Setup auth module [RUNNING]  │
│  □ F1-T2: Add login endpoint [READY]   │
│  ⊗ F1-T3: Add logout endpoint [BLOCKED]│
│     Dependencies: F1-T2                 │
│  ■ F1-T0: Create auth types [DONE]     │
├─────────────────────────────────────────┤
│ Progress: 1/4 tasks (25%)               │
│ Current: F1-T1 (iteration 2/10)         │
└─────────────────────────────────────────┘
```

**Status Icons:**
- `▶` = Running (current task in execution)
- `■` = Complete (passes: true)
- `□` = Ready (dependencies met, waiting)
- `⊗` = Blocked (has unmet dependencies)

**Dependency Display:**
- Shows blocking tasks para tasks ⊗
- Exemplo: "Dependencies: F1-T1, F1-T2"

**Color Coding:**
```bash
# lib/tui.sh
GREEN="\033[0;32m"   # Complete tasks
YELLOW="\033[1;33m"  # Running task
RED="\033[0;31m"     # Blocked tasks
BLUE="\033[0;34m"    # Ready tasks
```

**Update Frequency:**
- Real-time updates via shell signals
- Refresh on cada task state change
- Clear screen + redraw completo

### 2.7 Generator

#### Interactive Task Creation

**Localização:** lib/generator.sh

**Fluxo:**
```
1. Ask: Feature ID (F1, F2, ...)
2. Ask: Feature name
3. Ask: Feature description
4. Ask: Number of tasks
5. For each task:
   - Task title
   - Task description
   - Priority (1-10)
   - Dependencies (comma-separated: F1-T1,F1-T2)
   - Dependency mode (all/any) - only if dependencies provided
   - Context files (optional)
   - Context libraries (optional)
   - Context hints (optional)
   - Acceptance criteria (line by line, empty to finish)
   - Test command (default: npm test)
6. Write to prp.json
7. Initialize progress.txt
```

**Dependency Input Parsing:**
```bash
# Input: "F1-T1,F1-T2, F1-T3"
# Output: ["F1-T1", "F1-T2", "F1-T3"]

IFS=',' read -ra deps <<< "$dependency_input"
for dep in "${deps[@]}"; do
    dep=$(echo "$dep" | xargs)  # Trim whitespace
    json_deps+=("\"$dep\"")
done
```

**Mode Selection:**
```bash
# Only ask for mode if dependencies provided
if [ ${#deps[@]} -gt 0 ]; then
    echo "Dependency mode (all/any)? [all]"
    read dependency_mode
    dependency_mode=${dependency_mode:-all}
fi
```

**Output:** prp.json completo e válido

---

## 3. Pain Points Identificados

### 3.1 CRÍTICO: Lack of Error Classification

**Problema:**
```
Erro: "npm run db:push" não existe
→ Rollback → Retry
→ Erro: "npm run db:push" não existe (MESMO ERRO)
→ Rollback → Retry
→ Loop infinito até MAX_ITERATIONS
```

**Causa Raiz:**
- Todos os erros tratados identicamente
- Sem distinção entre ENVIRONMENT vs CODE errors
- Sem validação de comandos ANTES de executar

**Impacto:**
- 🔥 **Crítico**: Desperdício de 5-8 iterações em erros triviais
- ⏱️ **Tempo**: ~10min por loop infinito (5 iter × 2min cada)
- 💰 **Custo**: Tokens desperdiçados em retries inúteis

**Exemplo Real:**
```
Task: "Add database migration"
Iteration 1: Claude tenta "npm run db:push"
Output: "npm ERR! missing script: db:push"
→ Rollback
Iteration 2: Claude tenta "npm run db:push" (AGAIN!)
Output: "npm ERR! missing script: db:push"
→ Rollback
...
Iteration 10: Timeout
```

**Solução Proposta:**
- PreToolUse hook para validar comandos npm
- Error classifier para distinguir ENVIRONMENT vs CODE
- Different retry strategy baseada em error type

### 3.2 ALTO: No Command Validation

**Problema:**
Claude tenta executar comandos que **certamente** vão falhar:
- npm scripts que não existem em package.json
- File paths que não existem
- git commands impossíveis

**Causa:**
- Sem validação ANTES de executar comando
- Claude "adivinha" comandos baseado em context
- Feedback só vem DEPOIS do erro

**Impacto:**
- Iterações desperdiçadas
- Context window poluído com error outputs
- Aprendizado lento (Claude só vê erro depois)

**Exemplo:**
```bash
# Claude tenta:
npm run typecheck

# Mas package.json só tem:
{
  "scripts": {
    "test": "jest",
    "build": "tsc"
  }
}

# Result: npm ERR! missing script: typecheck
```

**Solução Proposta:**
- PreToolUse hook com validações:
  - Verificar npm scripts em package.json
  - Verificar file paths existem
  - Bloquear comandos impossíveis (force push to main)

### 3.3 MÉDIO: Rollback Loses Partial Progress

**Problema:**
```
Claude fez mudanças:
- ✅ Criou 5 arquivos corretos
- ✅ Implementou 80% da funcionalidade
- ❌ 1 typo causou test failure

Git rollback:
- ❌ Descarta TUDO (100% das mudanças)
```

**Causa:**
- `git reset --hard` é all-or-nothing
- Sem granularidade (não pode preservar arquivos específicos)
- Sem partial commits

**Impacto:**
- Re-trabalho desnecessário
- Lentidão em tasks complexas
- Frustração (Claude refaz mesma coisa múltiplas vezes)

**Trade-off:**
- ✅ PRO: Simplicidade (git reset é rápido e confiável)
- ❌ CON: Perde partial progress

**Possível Solução:**
- Incremental testing (unit → integration → full)
- Partial commits (commit working files, rollback broken ones)
- File-level granularity (rollback só arquivos com erros)

**Complexidade:** Alta - requer refactor significativo do rollback mechanism

### 3.4 MÉDIO: No Timeout Handling

**Problema:**
```bash
# Test command pode travar indefinidamente
eval "$test_cmd" 2>&1 | tee "$test_output_file"

# Se test hangs (infinite loop, deadlock, etc):
# → Saci trava
# → Usuário precisa Ctrl+C
# → Nenhum cleanup automático
```

**Causa:**
- Sem timeout no `eval "$test_cmd"`
- Sem detection de hanging process
- Sem timeout no Claude CLI session

**Impacto:**
- Execuções travadas (precisa intervenção manual)
- Waste de tempo (user não percebe que travou)

**Solução Proposta:**
```bash
# Opção 1: timeout command
timeout 300 eval "$test_cmd"  # 5min timeout

# Opção 2: background + wait with timeout
eval "$test_cmd" &
pid=$!
sleep 300
if kill -0 $pid 2>/dev/null; then
    kill $pid
    LAST_ERROR="Test timeout after 5 minutes"
fi
```

### 3.5 BAIXO: Failed Tasks Skip to Next

**Problema:**
```
Task F1-T1 falha após 10 iterations
→ Skip to next task (F1-T2)
→ F1-T1 nunca é retried
→ Feature fica incompleta
```

**Causa:**
- No "defer for later" mechanism
- No retry queue
- Linear execution (task by task)

**Impacto:**
- Features incompletas
- Dependent tasks nunca executam (se dependency failed)

**Possível Solução:**
- Retry queue (failed tasks vão para fila de retry)
- Max retries per task (default: 3 attempts em diferentes momentos)
- User prompt on failure ("Skip or retry later?")

**Complexidade:** Média - requer state tracking de retry attempts

---

## 4. Oportunidades de Melhoria

### Tier 1 - CRÍTICO (Implementar Primeiro)

#### 4.1 PreToolUse Hook - Command Validator

**O que:** Validar comandos Bash ANTES de Claude executar

**Por que:** Resolve loop infinito em npm scripts inválidos

**Como:**
```python
# .saci/hooks/validate-bash.py

def validate_npm_script(command):
    match = re.search(r"npm run (\w+)", command)
    if match:
        script_name = match.group(1)
        if not script_exists_in_package_json(script_name):
            return {
                "permissionDecision": "deny",
                "permissionDecisionReason": f"Script '{script_name}' doesn't exist. Available: {list_available_scripts()}"
            }
    return {"permissionDecision": "allow"}
```

**Hook config:**
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "$CLAUDE_PROJECT_DIR/.saci/hooks/validate-bash.py"
      }]
    }]
  }
}
```

**ROI:** 🌟🌟🌟 CRÍTICO - Elimina 70% dos loops infinitos

**Complexidade:** Baixa (script Python simples)

#### 4.2 PostToolUse Hook - Error Classifier

**O que:** Classificar erros após execução

**Por que:** Permite retry strategies diferentes por tipo de erro

**Como:**
```python
# .saci/hooks/check-test-output.py

def classify_error(output):
    if "npm ERR! missing script" in output:
        return "ENVIRONMENT"
    if "ENOENT: no such file" in output:
        return "ENVIRONMENT"
    if "SyntaxError:" in output or "TypeError:" in output:
        return "CODE"
    if "FAIL" in output:
        return "CODE"
    return "UNKNOWN"
```

**Output:**
```json
{
  "decision": "block",
  "reason": "Test failed with CODE error: TypeError at line 42",
  "hookSpecificOutput": {
    "errorType": "CODE",
    "suggestion": "Check variable initialization"
  }
}
```

**ROI:** 🌟🌟 ALTO - Permite debug mode e smart retries

**Complexidade:** Baixa

#### 4.3 Stop Hook - Prevent Premature Exit

**O que:** Bloquear Claude de parar se testes ainda falham

**Por que:** Garantia adicional de quality (além do loop do Saci)

**Como:**
```python
# .saci/hooks/check-if-done.py

result = subprocess.run(["npm", "test"], capture_output=True)
if result.returncode != 0:
    return {
        "decision": "block",
        "reason": "Tests still failing. Must fix before stopping."
    }
```

**ROI:** 🌟 MÉDIO - Safety net contra premature exits

**Complexidade:** Muito Baixa

#### 4.4 Enhanced CLI Flags

**O que:** Usar mais flags do Claude CLI

**Por que:** Melhor debugging, controle, context injection

**Como:**
```bash
# Em saci.sh linha ~542
cli_cmd="claude --print \
  --dangerously-skip-permissions \
  --max-turns $MAX_ITERATIONS \
  --verbose \
  --append-system-prompt 'Iteration $iteration/$MAX_ITERATIONS. Error type: $ERROR_TYPE.'"
```

**Flags adicionados:**
- `--max-turns`: Fail-safe adicional
- `--verbose`: Logging detalhado
- `--append-system-prompt`: Context injection

**ROI:** 🌟 MÉDIO - Baixo esforço, melhoria tangível

**Complexidade:** Muito Baixa (1 linha de código)

### Tier 2 - IMPORTANTE

#### 4.5 UserPromptSubmit Hook - Auto Context

**O que:** Injetar contexto automático no início de cada iteração

**Por que:** Claude recebe info útil sem precisar buscar

**Como:**
```bash
# .saci/hooks/add-context.sh

echo "## Repo Context"
echo "- Branch: $(git branch --show-current)"
echo "- Uncommitted: $(git status --short | wc -l) files"
echo ""
echo "## Available npm scripts:"
npm run 2>&1 | grep "^  " | head -5
```

**ROI:** 🌟🌟 MÉDIO-ALTO - Reduz erros de "script não existe"

**Complexidade:** Baixa

#### 4.6 Subagent "environment-fixer"

**O que:** Delegar erros de ENVIRONMENT para subagent especializado

**Por que:** Different expertise para different error types

**Como:**
```bash
# Quando ERROR_TYPE = "ENVIRONMENT"
cat "$env_fix_prompt" | claude --print \
  --agents '{
    "environment-fixer": {
      "description": "Fix environment errors",
      "prompt": "You are a DevOps expert. Fix missing scripts, configs, deps.",
      "tools": ["Read", "Edit", "Bash"]
    }
  }'
```

**ROI:** 🌟🌟 MÉDIO - Melhora fix rate de ENVIRONMENT errors

**Complexidade:** Média (requer integração no loop)

#### 4.7 Error Classification Engine

**O que:** Sistema robusto de classificação de erros

**Por que:** Foundation para smart retries e debug mode

**Como:**
```bash
# Classificação hierárquica
ERROR_CATEGORY=$(classify_error_category "$error_output")
ERROR_TYPE=$(classify_error_type "$error_output")
ERROR_SEVERITY=$(classify_error_severity "$error_output")

# Exemplos:
# CATEGORY: ENVIRONMENT | CODE | INFRASTRUCTURE
# TYPE: missing_script | syntax_error | timeout
# SEVERITY: critical | high | medium | low
```

**ROI:** 🌟🌟 MÉDIO - Enables advanced features

**Complexidade:** Média-Alta

### Tier 3 - ÚTIL

#### 4.8 Background Task Execution

**O que:** Rodar testes longos em background

**Por que:** Não bloquear execução em testes de 5+ minutos

**Como:**
```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "npm run integration-tests",
    "run_in_background": true
  }
}
```

**ROI:** 🌟 BAIXO-MÉDIO - Útil para integration tests

**Complexidade:** Média (requer async handling)

**Nota:** Não urgente para Saci atual

#### 4.9 Incremental Testing

**O que:** Rodar unit → integration → full test suite

**Por que:** Fail faster, get feedback earlier

**Como:**
```bash
# Tier 1: Unit tests (fast)
npm run test:unit
[ $? -ne 0 ] && exit 1

# Tier 2: Integration tests
npm run test:integration
[ $? -ne 0 ] && exit 1

# Tier 3: Full suite
npm test
```

**ROI:** 🌟 MÉDIO - Faster feedback loop

**Complexidade:** Baixa (se tests já separados)

#### 4.10 Persistent Checkpoint System

**O que:** Salvar checkpoints em `.saci/checkpoints/`

**Por que:** Recovery se script crashar

**Como:**
```bash
# Save checkpoint
checkpoint_id="${task_id}_$(date +%s)"
mkdir -p .saci/checkpoints
cat > .saci/checkpoints/$checkpoint_id.json <<EOF
{
  "task_id": "$task_id",
  "iteration": $iteration,
  "git_hash": "$(git rev-parse HEAD)",
  "timestamp": "$(date -Iseconds)",
  "test_output": "$test_output"
}
EOF
```

**ROI:** 🌟 BAIXO - Nice to have

**Complexidade:** Baixa

---

## 5. Comparação com Competidores

### 5.1 Saci vs Ralph

| Aspecto | Saci | Ralph |
|---------|------|-------|
| **Dependencies** | ✅ DAG com cycle detection | ❌ Sem dependencies |
| **Rollback** | ✅ Git reset --hard | ❌ Sem rollback (|| true) |
| **TUI** | ✅ Real-time visualization | ❌ Plain text output |
| **Error Handling** | ⚠️ Basic (sem classification) | ❌ Ignora erros (|| true) |
| **Task States** | ✅ 4 states (pending, ready, running, done) | ⚠️ Apenas done/not done |
| **Retry Logic** | ✅ MAX_ITERATIONS com context | ⚠️ Single attempt |
| **Documentation** | ⚠️ Good code, lacks docs | ✅ Better README |
| **Archive System** | ❌ Sem archive | ✅ Salva todos os attempts |
| **Complexity** | 680 lines (médio) | 300 lines (simples) |

**Conclusão:**

**Vantagens do Saci:**
- ✅ Arquitetura superior (dependencies, states, rollback)
- ✅ Melhor controle (cycle detection, topological sort)
- ✅ TUI para visibility
- ✅ Fresh context window per iteration

**Vantagens do Ralph:**
- ✅ Simplicidade (menos código)
- ✅ Melhor documentação
- ✅ Archive system (preserva todos os attempts)

**Gap a preencher:**
- 🎯 Error intelligence (classificação, smart retries)
- 🎯 Command validation (hooks)
- 🎯 Better documentation

---

## 6. Métricas e KPIs

### 6.1 Métricas Atuais (Estimadas)

**Loop Efficiency:**
- Total iterations: 100
- Productive iterations (made progress): ~30
- Wasted iterations (retries sem progresso): ~70
- **Efficiency: ~30%**

**Commands Blocked:**
- Invalid commands attempted: ~15 per 10 tasks
- Commands blocked by validation: 0
- **Block rate: 0%**

**Iterations per Task:**
- Successful tasks: 1-3 iterations (average: 2)
- Failed tasks: 10 iterations (timeout)
- **Average: 4-6 iterations per task**

**Error Recovery:**
- ENVIRONMENT errors: ~40% (não resolvidos automaticamente)
- CODE errors: ~60% (resolvidos após retries)
- **Recovery rate: ~60%**

### 6.2 Targets Pós-Hooks

**Loop Efficiency:** >70%
- Productive iterations: 70+
- Wasted iterations: <30
- Melhoria: +40pp (100% improvement)

**Commands Blocked:** >2 per task
- Invalid commands prevented: 15
- Block rate: ~100% (quase todos bloqueados)
- Melhoria: From 0% to 100%

**Iterations per Task:** 1-3 (average: 2)
- Redução de 4-6 para 2
- Melhoria: -50% iterations

**Error Recovery:** >80%
- ENVIRONMENT errors: 80% (hooks + subagent)
- CODE errors: 80% (melhor classification)
- Melhoria: +20pp

### 6.3 Como Medir

**Instrumentação necessária:**

```bash
# Em saci.sh, adicionar tracking
log_metric() {
    local metric="$1"
    local value="$2"
    echo "$(date -Iseconds),$metric,$value" >> .saci/metrics.csv
}

# Exemplos:
log_metric "iteration_result" "productive"  # ou "wasted"
log_metric "command_blocked" "npm run db:push"
log_metric "error_type" "ENVIRONMENT"
log_metric "task_completed_iterations" "3"
```

**Dashboard:**
```bash
# Generate report
./saci metrics

# Output:
┌─────────────────────────────┐
│ Saci Metrics (Last 7 Days)  │
├─────────────────────────────┤
│ Loop Efficiency: 72%        │
│ Commands Blocked: 23        │
│ Avg Iterations: 2.1         │
│ Error Recovery: 78%         │
└─────────────────────────────┘
```

---

## 🎯 Conclusão

**Estado Atual:**
Saci tem **arquitetura superior** (dependencies, rollback, TUI) mas **falta error intelligence**.

**Maior Pain Point:**
Loop infinito em ENVIRONMENT errors (npm scripts inválidos).

**Solução de Maior Impacto:**
Implementar sistema de **hooks** do Claude Code para:
1. Validar comandos ANTES de executar (PreToolUse)
2. Classificar erros DEPOIS de executar (PostToolUse)
3. Prevenir paradas prematuras (Stop)
4. Injetar contexto automático (UserPromptSubmit)

**ROI Estimado:**
- ⏱️ **Tempo:** -50% no tempo total (menos iterações)
- 💰 **Custo:** -40% em tokens (menos retries)
- ✅ **Qualidade:** +20pp em error recovery rate

**Próximo Passo:**
Implementar hooks conforme plano detalhado.

---

## 📚 Referências

- `.claude/docs/hooks.md` - Claude Code hooks reference
- `.claude/docs/cli-reference.md` - CLI flags disponíveis
- `.claude/docs/sub-agents.md` - Subagents para debug mode
- `saci.sh` - Código principal (680 lines)
- Ralph comparison - `data.txt`
