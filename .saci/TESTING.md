# Saci Hooks Testing Guide

Este guia explica como testar o sistema de hooks antes de usar em produção.

---

## 🚀 Quick Start

### Teste Automatizado (Recomendado)

```bash
# Rodar todos os testes
.saci/test-hooks.sh

# Resultado esperado: "✓ ALL TESTS PASSED!"
```

Este script testa:
- ✅ Cada hook individualmente com casos válidos e inválidos
- ✅ Classificação de erros (ENVIRONMENT vs CODE)
- ✅ Permissões de arquivos (executável)
- ✅ Configuração do settings.json

---

## 📋 Testes Detalhados por Hook

### 1. PreToolUse Hook (validate-bash.py)

**Objetivo:** Bloquear comandos inválidos ANTES de executar

#### Teste Manual 1.1: npm script válido

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' | \
  .saci/hooks/validate-bash.py

# Esperado:
# - Exit code: 0 (permitir)
# - Output: vazio ou success message
```

#### Teste Manual 1.2: npm script inválido

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"npm run db:push"}}' | \
  .saci/hooks/validate-bash.py

# Esperado:
# - Exit code: 0 com JSON output
# - JSON contém: "permissionDecision": "deny"
# - Reason: "Script 'db:push' does not exist. Available scripts: test, build..."
```

#### Teste Manual 1.3: git force push to main (perigoso)

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}' | \
  .saci/hooks/validate-bash.py

# Esperado:
# - JSON contém: "permissionDecision": "deny"
# - Reason: "Force push to main/master branch is blocked"
```

#### Teste Manual 1.4: comando normal

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | \
  .saci/hooks/validate-bash.py

# Esperado:
# - Exit code: 0 (permitir)
```

---

### 2. PostToolUse Hook (check-test-output.py)

**Objetivo:** Classificar tipo de erro após execução

#### Teste Manual 2.1: ENVIRONMENT error

```bash
echo '{"tool_response":"npm ERR! missing script: db:push"}' | \
  .saci/hooks/check-test-output.py

# Esperado:
# - JSON output com: "errorType": "ENVIRONMENT"
# - Suggestion: "Check package.json for available scripts"
```

#### Teste Manual 2.2: CODE error (TypeError)

```bash
cat <<'EOF' | .saci/hooks/check-test-output.py
{"tool_response":"TypeError: Cannot read property 'map' of undefined\n    at Object.<anonymous> (/path/file.ts:42:15)"}
EOF

# Esperado:
# - JSON output com: "errorType": "CODE"
# - Details: "file": "file.ts", "line": "42"
# - Suggestion sobre type error
```

#### Teste Manual 2.3: Test failure

```bash
cat <<'EOF' | .saci/hooks/check-test-output.py
{"tool_response":"FAIL src/auth.test.ts\n  ● Authentication › login\n    Expected true but got false\n  5 tests failed"}
EOF

# Esperado:
# - JSON output com: "errorType": "CODE"
# - Reason: "Tests failed"
```

#### Teste Manual 2.4: File not found

```bash
echo '{"tool_response":"ENOENT: no such file or directory, open \"/path/to/missing.txt\""}' | \
  .saci/hooks/check-test-output.py

# Esperado:
# - JSON output com: "errorType": "ENVIRONMENT"
# - Reason: "File or directory not found"
```

---

### 3. Stop Hook (check-if-done.py)

**Objetivo:** Prevenir Claude de parar quando tests ainda falham

#### Teste Manual 3.1: Execução básica

```bash
echo '{}' | .saci/hooks/check-if-done.py

# Comportamento:
# - Se package.json existe:
#   - Roda "npm test"
#   - Se tests pass: exit 0 (allow stop)
#   - Se tests fail: JSON com "decision": "block"
# - Se package.json não existe:
#   - exit 0 (allow stop - não é projeto Node)
```

#### Teste Manual 3.2: Com tests falhando (simulação)

```bash
# Temporariamente quebrar um test para simular
# Depois rodar:
echo '{}' | .saci/hooks/check-if-done.py

# Esperado (se tests falham):
# - JSON: {"decision": "block", "reason": "Tests are still failing..."}
```

---

### 4. UserPromptSubmit Hook (add-context.sh)

**Objetivo:** Injetar contexto útil automaticamente

#### Teste Manual 4.1: Execução básica

```bash
.saci/hooks/add-context.sh

# Esperado:
# Output contém:
# - "## 🔍 Repository Context"
# - "Branch: <current-branch>"
# - "Available npm Scripts:"
# - Lista de scripts do package.json
```

#### Teste Manual 4.2: Verificar contexto completo

```bash
.saci/hooks/add-context.sh | head -30

# Deve incluir:
# - Git status (branch, uncommitted files)
# - Recent commits (last 3)
# - npm scripts disponíveis
# - Last npm error (se houver)
# - Project type (React/Next.js/TypeScript)
```

---

## 🧪 Teste de Integração com Claude Code

### Teste Integration 1: Rodar hooks no Claude Code

```bash
# 1. Abrir Claude Code em modo interativo
claude

# 2. Tentar comando inválido
> Can you run "npm run nonexistent-script"?

# Esperado:
# - PreToolUse hook bloqueia comando
# - Claude recebe mensagem: "Script 'nonexistent-script' does not exist"
# - Claude sugere script correto
```

### Teste Integration 2: Verificar classificação de erros

```bash
# 1. Criar task que vai falhar com ENVIRONMENT error
# 2. Rodar task
# 3. Ver logs em .claude/ para verificar PostToolUse hook

# OU

# Rodar Claude Code com --verbose para ver hook execution
claude --verbose
```

### Teste Integration 3: Verificar context injection

```bash
# 1. Abrir Claude Code
claude

# 2. Perguntar algo simples
> What npm scripts are available?

# Esperado:
# - UserPromptSubmit hook injeta lista de scripts
# - Claude responde sem ter que buscar
```

---

## 🎯 Teste End-to-End com Saci

### Setup: Criar Task de Teste

Criar `test-prp.json`:

```json
{
  "project": {
    "name": "Hook Test",
    "description": "Test hooks system",
    "branchName": "test/hooks"
  },
  "features": [
    {
      "id": "TEST",
      "name": "Hook Testing",
      "priority": 1,
      "tasks": [
        {
          "id": "TEST-T1",
          "title": "Try invalid npm script",
          "description": "Attempt to run 'npm run invalid-script-xyz' and see if hook blocks it",
          "priority": 1,
          "passes": false,
          "dependencies": [],
          "acceptance": [
            "Hook blocks invalid npm script",
            "Claude receives helpful error message",
            "Claude uses correct script instead"
          ],
          "tests": {
            "command": "echo 'Skipping tests for hook validation'"
          }
        }
      ]
    }
  ]
}
```

### Executar Teste E2E

```bash
# 1. Backup do prp.json atual (se houver)
cp prp.json prp.json.backup

# 2. Usar test PRP
cp test-prp.json prp.json

# 3. Rodar Saci
./saci.sh

# 4. Observar logs
# - Verificar se PreToolUse hook bloqueia comando inválido
# - Verificar se Claude recebe feedback correto
# - Verificar se PostToolUse classifica erros

# 5. Restaurar PRP original
mv prp.json.backup prp.json
```

### Validar Hooks Funcionaram

Verificar nos logs:

```bash
# Logs do Claude Code (se verbose ativado)
tail -f /tmp/claude-*.log

# Ou verificar output do Saci diretamente
# Procurar por mensagens de hook:
# - "permissionDecision": "deny"
# - "errorType": "ENVIRONMENT" ou "CODE"
```

---

## ✅ Checklist de Validação

Antes de usar hooks em produção, verificar:

- [ ] Script `.saci/test-hooks.sh` passa todos os testes
- [ ] Todos os hooks são executáveis (`chmod +x`)
- [ ] `.claude/settings.json` tem sintaxe JSON válida
- [ ] Hooks configurados em settings.json (4 hooks)
- [ ] PreToolUse bloqueia npm scripts inválidos
- [ ] PostToolUse classifica erros corretamente
- [ ] Stop hook previne parada prematura
- [ ] UserPromptSubmit injeta contexto útil
- [ ] Teste end-to-end com Saci funciona

---

## 🐛 Troubleshooting

### Problema: Hook não executa

**Sintomas:** Claude não recebe feedback do hook

**Possíveis causas:**
1. Hook não é executável → `chmod +x .saci/hooks/*.py .saci/hooks/*.sh`
2. Caminho errado no settings.json → Verificar `$CLAUDE_PROJECT_DIR` expande corretamente
3. Timeout muito curto → Aumentar timeout em settings.json
4. Erro no script → Rodar hook manualmente para ver erro

**Debug:**
```bash
# Testar hook manualmente
echo '{"tool_input":{"command":"npm test"}}' | .saci/hooks/validate-bash.py

# Verificar exit code
echo $?

# Ver stderr
echo '{"tool_input":{"command":"npm test"}}' | .saci/hooks/validate-bash.py 2>&1
```

### Problema: Hook bloqueia comando válido

**Sintomas:** Claude não consegue rodar comandos legítimos

**Soluções:**
1. Verificar lógica de validação em `validate-bash.py`
2. Adicionar exceção para comandos específicos
3. Ajustar regex patterns

### Problema: Classificação de erro incorreta

**Sintomas:** PostToolUse classifica ENVIRONMENT como CODE ou vice-versa

**Soluções:**
1. Adicionar pattern específico em `check-test-output.py`
2. Melhorar regex patterns
3. Adicionar logging para debug

### Problema: Settings.json não é lido

**Sintomas:** Hooks configurados mas não executam

**Verificação:**
```bash
# Validar JSON
jq empty .claude/settings.json

# Ver configuração
jq '.hooks' .claude/settings.json

# Verificar se Claude Code encontra o arquivo
claude --help | grep -i settings
```

---

## 📊 Métricas de Sucesso

Após implementar hooks, medir:

### Antes dos Hooks (baseline)
- Loop efficiency: ~30%
- Invalid commands attempted: ~5-10 per task
- Commands blocked: 0
- Average iterations per task: 4-6

### Depois dos Hooks (target)
- Loop efficiency: >70%
- Invalid commands blocked: >2 per task
- Average iterations per task: 1-3

### Como medir

Adicionar logging no saci.sh:

```bash
# Contar iterações produtivas vs wasted
if [ $changed_files -gt 0 ]; then
    echo "productive" >> .saci/metrics.txt
else
    echo "wasted" >> .saci/metrics.txt
fi

# Depois calcular efficiency
productive=$(grep "productive" .saci/metrics.txt | wc -l)
total=$(wc -l < .saci/metrics.txt)
efficiency=$((productive * 100 / total))
echo "Loop efficiency: $efficiency%"
```

---

## 🚀 Próximos Passos

Depois de validar hooks:

1. **Rodar em tasks reais** - Testar com PRP de produção
2. **Monitorar métricas** - Acompanhar loop efficiency
3. **Ajustar patterns** - Melhorar validações baseado em feedback
4. **Implementar debug mode** - Usar error classification para delegar para subagents
5. **Adicionar mais validações** - git commands, file operations, etc.

---

## 📚 Referências

- [Hooks Reference](../.claude/docs/hooks.md) - Documentação completa dos hooks
- [Saci Analysis](../.claude/docs/saci-analysis.md) - Análise do sistema Saci
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide.md) - Guia oficial
