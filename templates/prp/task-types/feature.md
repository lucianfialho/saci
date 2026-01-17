## Task Context Layer (New Feature Implementation)

**Primary Objective**: Implement new feature that adds value while maintaining code quality and system stability

**Success Criteria**:
- Feature works as described in acceptance criteria
- All existing tests still pass (no regressions)
- New tests added for new functionality
- Code follows existing patterns and conventions
- Documentation updated if needed (README, inline comments, API docs)
- No security vulnerabilities introduced

**Input Requirements**:
- Clear feature description (what is being built)
- Acceptance criteria (how to know it's done)
- Test requirements (what needs to be tested)
- Context hints (relevant files, libraries, patterns to follow)

**Quality Standards**:
- Code coverage maintained or improved
- No performance regressions
- Follows existing architecture patterns
- Backwards compatible (unless explicitly stated otherwise)
- Error handling is comprehensive
- Edge cases are considered

**Implementation Checklist**:
1. ✓ **Read acceptance criteria carefully** - Understand all requirements before coding
2. ✓ **Check existing code for similar patterns** - Don't reinvent the wheel
3. ✓ **Identify files that need modification** - Plan before changing code
4. ✓ **Implement feature incrementally** - Small changes, test frequently
5. ✓ **Write/update tests** - Cover new functionality and edge cases
6. ✓ **Run full test suite** - Ensure no regressions
7. ✓ **Update documentation** - README, inline comments, API docs if needed
8. ✓ **Commit with descriptive message** - Explain what and why

**Common Pitfalls to Avoid**:
- Implementing more than what's asked (scope creep)
- Breaking existing functionality (always run tests)
- Inconsistent code style (follow existing patterns)
- Missing edge cases (null values, empty arrays, error states)
- Poor error handling (validate inputs, handle failures gracefully)
- Forgetting to update documentation
- Not considering performance implications
- Introducing security vulnerabilities

**Before Committing**:
- [ ] All acceptance criteria met?
- [ ] Tests passing (new and existing)?
- [ ] Code follows existing patterns?
- [ ] No console errors or warnings?
- [ ] Documentation updated?
- [ ] Commit message is clear and descriptive?

**Progress Documentation**:
After completing the feature, add entry to progress.txt with:
- What was implemented (high-level summary)
- Files changed (list of modified files)
- Key decisions made (architecture choices, trade-offs)
- Learnings (gotchas, patterns discovered, things to remember)
