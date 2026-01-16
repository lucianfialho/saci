# Claude Code Checkpointing

> Sistema de undo automático do Claude Code
> Fonte: https://code.claude.com/docs/en/checkpointing.md

---

## 🎯 O que é

Claude Code automaticamente trackeia edições de arquivos, permitindo **rewind** para estados anteriores.

### Como funciona:
- **Checkpoint criado:** Antes de cada edit
- **Persiste:** Across sessions (30 dias)
- **Rewind:** `Esc` + `Esc` ou `/rewind`

### Opções de Rewind:
1. **Conversation only** - Mantém código, volta conversa
2. **Code only** - Reverte arquivos, mantém conversa
3. **Both** - Volta tudo

---

## 🤔 Comparação com Saci

### **Claude Code Checkpointing:**
```
Edit file → Checkpoint automático → Pode fazer rewind
```

### **Saci Rollback:**
```bash
# Checkpoint manual via git
git_checkpoint=$(git rev-parse HEAD)

# Rollback se tests falham
git reset --hard "$git_checkpoint"
git clean -fd -e prp.json -e progress.txt
```

---

## ⚖️ Saci vs Claude Code

| Aspecto | Saci | Claude Code |
|---------|------|-------------|
| **Quando checkpoint** | Antes de cada iteração | Antes de cada edit |
| **Granularidade** | Por iteração completa | Por file edit |
| **Rollback** | Git reset --hard | Rewind seletivo |
| **Opções** | All or nothing | Conversation/Code/Both |
| **Persistência** | Git history | 30 dias |

---

## 💡 Insights

### **Vantagem Saci:**
- ✅ Git-based = Versionamento real
- ✅ Integra com workflow normal
- ✅ Commits no histórico (rastreabilidade)

### **Vantagem Claude Code:**
- ✅ Granularidade por file
- ✅ Rewind seletivo (conversation vs code)
- ✅ UI amigável (Esc + Esc)

---

## ⚠️ Limitações do Checkpointing

Claude Code **NÃO trackeeia:**
- ❌ Bash commands (rm, mv, cp)
- ❌ External changes (fora da sessão)
- ❌ Manual edits do usuário

**Quote da doc:**
> "Checkpoints are designed for quick, session-level recovery. For permanent version history and collaboration, continue using version control (Git)."

---

## 🎯 Conclusão

**Saci já tem um sistema superior:**
- Git rollback é mais robusto
- Checkpoint por iteração é suficiente
- Não precisa implementar checkpointing estilo Claude Code

**Foco deve estar em:**
- Error classification (hooks!)
- Smart recovery (debug mode)
- NOT checkpointing granular

---

## 📚 Links

- [Hooks](./hooks.md) - Melhor investimento de tempo
- [Interactive Mode](./interactive-mode.md) - Features interativas
