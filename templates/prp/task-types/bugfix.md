## Task Context Layer (Bug Fix)

**Primary Objective**: Identify root cause, fix the bug, prevent regressions, and ensure the issue is resolved

**Success Criteria**:
- Bug is reproducible (write a failing test first)
- Root cause is identified and documented
- Fix resolves the issue without introducing new bugs
- Test added to prevent regression
- All existing tests still pass
- Related edge cases are checked

**Input Requirements**:
- Bug description (what is broken)
- Steps to reproduce (how to trigger the bug)
- Expected vs actual behavior (what should happen vs what happens)
- Error messages or logs (if available)
- Context (affected files, recent changes)

**Quality Standards**:
- Fix addresses root cause, not just symptoms
- No workarounds or hacks (proper fix)
- Minimal changes (only fix what's broken)
- Test coverage for the bug scenario
- Documentation updated if behavior changes

**Bug Fixing Workflow**:
1. ✓ **Reproduce the bug** - Verify it exists and understand when it happens
2. ✓ **Write a failing test** - Captures the bug behavior (TDD approach)
3. ✓ **Investigate root cause** - Debug, read code, check logs, trace execution
4. ✓ **Identify the fix** - Understand what needs to change and why
5. ✓ **Implement the fix** - Make minimal changes to resolve the issue
6. ✓ **Verify the test passes** - Confirm the bug is fixed
7. ✓ **Run full test suite** - Ensure no regressions introduced
8. ✓ **Check related edge cases** - Are there similar scenarios that might be broken?
9. ✓ **Commit with clear message** - Explain what was broken and how it's fixed

**Debugging Strategies**:
- Read error messages carefully (often they tell you exactly what's wrong)
- Use console.log / print statements strategically
- Check recent changes (git log, git diff) - did something break this?
- Simplify the problem - create minimal reproduction
- Verify assumptions - is data what you expect?
- Check documentation - is the API being used correctly?
- Use debugger breakpoints to step through code
- Review test output for clues

**Common Bug Categories**:
- **Logic errors** - Incorrect conditions, off-by-one errors, wrong operators
- **Null/undefined** - Missing null checks, accessing properties on undefined
- **Type mismatches** - String vs number, array vs object
- **Async issues** - Race conditions, missing await, callback hell
- **State management** - Stale state, incorrect state updates, missing dependencies
- **Edge cases** - Empty arrays, zero values, boundary conditions
- **Environment** - Missing env vars, incorrect configuration, version mismatches

**Root Cause Analysis**:
Ask these questions:
- What is the immediate cause of the bug?
- What is the underlying reason this happened?
- Why wasn't this caught earlier (missing test)?
- Are there other places with similar issues?
- How can we prevent this category of bug in the future?

**Before Committing**:
- [ ] Bug is reproducible and root cause is identified?
- [ ] Failing test written (and now passes)?
- [ ] Fix is minimal and addresses root cause?
- [ ] All tests passing?
- [ ] Related edge cases checked?
- [ ] Commit message explains what was broken and how it's fixed?

**Commit Message Format**:
```
fix: [brief description of what was broken] [task-id]

- Problem: [describe the bug and impact]
- Root cause: [explain what caused it]
- Solution: [explain the fix]
- Testing: [how it was verified]

Co-Authored-By: Saci <noreply@saci.sh>
```

**Progress Documentation**:
After fixing the bug, add entry to progress.txt with:
- What was broken (symptom and root cause)
- How it was fixed (changes made)
- Test added to prevent regression
- Related issues or edge cases addressed
- Learnings (how to avoid similar bugs)
