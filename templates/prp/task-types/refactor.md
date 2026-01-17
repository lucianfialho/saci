## Task Context Layer (Code Refactoring)

**Primary Objective**: Improve code quality, maintainability, or performance WITHOUT changing external behavior

**Success Criteria**:
- External behavior remains unchanged (all tests still pass)
- Code is more readable, maintainable, or performant
- Technical debt is reduced
- Code follows best practices and patterns
- No new bugs introduced
- Documentation updated to reflect new structure (if significant)

**Input Requirements**:
- What needs to be refactored (specific code, file, module)
- Why it needs refactoring (tech debt, performance, readability)
- Success criteria (what "better" looks like)
- Constraints (what must stay the same)

**Quality Standards**:
- All existing tests must pass (verify behavior is unchanged)
- Code coverage maintained or improved
- No performance regressions (measure before/after if performance-focused)
- Follows language/framework best practices
- Consistent with codebase patterns
- Changes are well-documented in commit message

**Types of Refactoring**:

**Code Organization**:
- Extract functions/methods (reduce complexity)
- Split large files into smaller modules
- Group related functionality
- Remove dead code
- Consolidate duplicated code

**Naming & Clarity**:
- Rename variables/functions for clarity
- Use descriptive names
- Follow naming conventions
- Add/update comments where logic is complex

**Performance**:
- Optimize algorithms (reduce time complexity)
- Reduce memory usage
- Add caching where appropriate
- Remove unnecessary computations
- Optimize database queries

**Architecture**:
- Improve separation of concerns
- Apply design patterns appropriately
- Reduce coupling between modules
- Improve testability

**Refactoring Workflow**:
1. ✓ **Ensure tests exist** - If not, write tests first (safety net)
2. ✓ **Run tests to establish baseline** - All should pass before refactoring
3. ✓ **Make incremental changes** - Small steps, test frequently
4. ✓ **Run tests after each change** - Catch regressions immediately
5. ✓ **Verify behavior unchanged** - External contracts stay the same
6. ✓ **Measure improvements** - Performance, readability, maintainability
7. ✓ **Update documentation** - Comments, README, architecture docs
8. ✓ **Commit with clear rationale** - Explain why refactoring was needed

**Refactoring Strategies**:
- **Red-Green-Refactor** (TDD) - Tests first, then refactor
- **Strangler Fig Pattern** - Gradually replace old code with new
- **Branch by Abstraction** - Add abstraction layer, migrate incrementally
- **Extract Method** - Pull out complex logic into named functions
- **Extract Variable** - Name complex expressions
- **Inline** - Remove unnecessary abstractions
- **Replace Conditional with Polymorphism** - For complex switch/if chains

**Common Refactoring Patterns**:
- Extract reusable utilities from duplicated code
- Replace magic numbers/strings with named constants
- Convert callback hell to async/await
- Replace prop drilling with Context API
- Split god classes/components into focused units
- Replace complex conditionals with early returns
- Use TypeScript types instead of runtime checks

**Before Committing**:
- [ ] All tests passing (behavior unchanged)?
- [ ] Code is more readable/maintainable/performant?
- [ ] No new bugs introduced?
- [ ] Dead code removed?
- [ ] Documentation updated?
- [ ] Commit message explains the "why"?

**Commit Message Format**:
```
refactor: [what was refactored] [task-id]

- Reason: [why refactoring was needed - tech debt, performance, etc.]
- Changes: [high-level summary of structural changes]
- Impact: [readability improvement, performance gain, reduced complexity]
- Testing: [how behavior was verified unchanged]

Co-Authored-By: Saci <noreply@saci.sh>
```

**Red Flags (When to Stop)**:
- Tests start failing (behavior is changing)
- Scope is expanding (refactor ONE thing at a time)
- Changes are too large (break into smaller steps)
- You're rewriting instead of refactoring (different goal)
- Performance is degrading (measure before/after)

**Progress Documentation**:
After refactoring, add entry to progress.txt with:
- What was refactored (files/modules changed)
- Why it needed refactoring (original problem)
- How it was improved (specific changes)
- Metrics (if applicable - LOC reduced, complexity decreased, perf improved)
- Learnings (patterns to apply elsewhere, gotchas to remember)
