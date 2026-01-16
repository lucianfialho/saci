# Resumo: Claude Code Features para o Saci

> Análise de relevância das features do Claude Code para implementar debug mode inteligente no Saci

---

## 🎯 Ordem de Prioridade

### 1. **HOOKS** 🌟🌟🌟 (CRÍTICO)
**Por que:** Resolve o problema central do Saci - classificar erros ANTES de executar comandos

**Arquivos:**
- [hooks.md](./hooks.md) - Referência completa
- [hooks-guide.md](./hooks-guide.md) - Exemplos práticos

**O que implementar:**
- `PreToolUse` para validar comandos Bash
- `PostToolUse` para detectar falhas de teste
- `UserPromptSubmit` para injetar contexto automático
- `Stop` para prevenir stop prematuro

**ROI:** 🌟🌟🌟 ALTÍSSIMO - Resolve o loop infinito

---

### 2. **SUB-AGENTS** 🌟🌟 (IMPORTANTE)
**Por que:** Debug mode pode rodar em contexto separado

**Arquivos:**
- [sub-agents.md](./sub-agents.md)

**O que implementar:**
```bash
--agents '{
  "environment-fixer": {
    "description": "Fix environment errors",
    "prompt": "You are a DevOps expert...",
    "tools": ["Read", "Edit", "Bash"]
  }
}'
```

**ROI:** 🌟🌟 ALTO - Útil para debug mode isolado

---

### 3. **CLI FLAGS** 🌟 (ÚTIL)
**Por que:** Melhorar controle sobre execução do Saci

**Arquivos:**
- [cli-reference.md](./cli-reference.md)

**O que usar:**
```bash
cat prompt.md | claude \
  --dangerously-skip-permissions \
  --max-turns "$MAX_ITERATIONS" \
  --output-format json \
  --verbose \
  --append-system-prompt "Iteration $i. Previous error: $LAST_ERROR"
```

**ROI:** 🌟 MÉDIO - Melhorias incrementais

---

### 4. **BACKGROUND TASKS** 🌟 (INTERESSANTE)
**Por que:** Testes longos não bloqueariam o loop

**Arquivos:**
- [interactive-mode.md](./interactive-mode.md)

**O que usar:**
```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "npm test",
    "run_in_background": true
  }
}
```

**ROI:** 🌟 BAIXO-MÉDIO - Útil mas não urgente

---

### 5. **MCP** ⚠️ (BAIXA PRIORIDADE)
**Por que:** Integração com ferramentas externas

**Arquivos:**
- [mcp.md] - (não criado, baixa relevância)

**ROI:** ⚠️ BAIXO - Não resolve problema atual

---

### 6. **SKILLS** ⚠️ (BAIXA PRIORIDADE)
**Por que:** Saci roda em modo headless, Skills são para interativo

**Arquivos:**
- [skills.md](./skills.md)

**ROI:** ⚠️ BAIXO - Não aplicável ao Saci

---

### 7. **PLUGINS** ⚠️ (NÃO RELEVANTE)
**Por que:** Saci não precisa de sistema de plugins

**Arquivos:**
- [plugins.md] - (não criado)
- [discover-plugins.md] - (não criado)

**ROI:** ⚠️ ZERO - Não aplicável

---

### 8. **OUTPUT STYLES** ⚠️ (NÃO RELEVANTE)
**Por que:** Customização de output do Claude Code

**Arquivos:**
- [output-styles.md] - (não criado)

**ROI:** ⚠️ ZERO - Não aplicável

---

### 9. **HEADLESS MODE** ✅ (JÁ USADO)
**Por que:** Saci já usa `-p` flag

**Arquivos:**
- [headless.md] - (não criado, já sabemos usar)

**ROI:** ✅ JÁ IMPLEMENTADO

---

### 10. **TROUBLESHOOTING** 📚 (REFERÊNCIA)
**Por que:** Guia de troubleshooting geral

**Arquivos:**
- [troubleshooting.md] - (não criado, referência apenas)

**ROI:** 📚 DOCUMENTAÇÃO - Não para implementação

---

### 11. **CHECKPOINTING** ❌ (NÃO USAR)
**Por que:** Git rollback do Saci é superior

**Arquivos:**
- [checkpointing.md](./checkpointing.md)

**Conclusão:** Saci já tem sistema melhor

**ROI:** ❌ ZERO - Não implementar

---

## 📋 Plano de Ação

### Fase 1: Error Classification (CRÍTICO)
1. Criar `.saci/hooks/` directory
2. Implementar `PreToolUse` hook para validar comandos
3. Script Python para classificar ENVIRONMENT vs CODE errors
4. Bloquear comandos ruins ANTES de executar

**Resultado esperado:**
```
Erro: "npm run db:push" não existe
Hook PreToolUse: BLOQUEIA comando
Claude recebe: "Use npm run db:migrate instead"
Claude executa: comando correto ✅
```

### Fase 2: Debug Mode (IMPORTANTE)
1. Criar subagent `environment-fixer`
2. Hook detecta erro ENVIRONMENT
3. Saci delega para subagent
4. Subagent fix + retorna

### Fase 3: Melhorias Incrementais (ÚTIL)
1. Adicionar flags úteis (`--max-turns`, `--verbose`, etc)
2. Implementar background tasks (se necessário)
3. Context injection via `--append-system-prompt`

---

## 🎯 Foco Imediato

**PRIORIDADE MÁXIMA:**

1. **Hooks Reference** ([hooks.md](./hooks.md))
2. **Hooks Guide** ([hooks-guide.md](./hooks-guide.md))
3. **CLI Reference** ([cli-reference.md](./cli-reference.md))

**IMPLEMENTAR PRIMEIRO:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.saci/hooks/validate-bash.py"
          }
        ]
      }
    ]
  }
}
```

---

## 📚 Documentação Criada

### Arquivos com conteúdo detalhado:
- ✅ [README.md](./README.md)
- ✅ [cli-reference.md](./cli-reference.md)
- ✅ [interactive-mode.md](./interactive-mode.md)
- ✅ [checkpointing.md](./checkpointing.md)
- ✅ [hooks.md](./hooks.md) - **MAIS IMPORTANTE**
- ✅ [hooks-guide.md](./hooks-guide.md) - **EXEMPLOS PRÁTICOS**
- ✅ [skills.md](./skills.md)
- ✅ [sub-agents.md](./sub-agents.md)
- ✅ [summary.md](./summary.md) - **ESTE ARQUIVO**

### Arquivos não criados (baixa relevância):
- ❌ mcp.md (external tools - baixa prioridade)
- ❌ headless.md (já usamos `-p`)
- ❌ troubleshooting.md (referência geral)
- ❌ plugins.md (não aplicável)
- ❌ discover-plugins.md (não aplicável)
- ❌ output-styles.md (não aplicável)

---

## 🔥 Próximo Passo

**Implementar `.saci/hooks/validate-bash.py`** seguindo exemplos do [hooks-guide.md](./hooks-guide.md)
