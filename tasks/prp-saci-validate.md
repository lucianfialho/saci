# PRP: Saci Validate Command

## Introduction
Add a comprehensive `saci validate` command that validates PRP files before execution, providing clear feedback and educational guidance to prevent runtime errors and improve PRP quality.

## Goals
- Validate prp.json structure against schema requirements
- Detect circular dependencies and invalid task references
- Verify all required fields are present and correctly formatted
- Provide actionable error messages with suggestions
- Educate users on PRP best practices through interactive feedback
- Reduce wasted iterations from invalid PRP configurations

## User Stories

### US-001: Validate JSON syntax and structure
**Description:** As a developer, I need to verify the PRP file has valid JSON syntax and follows the expected schema so errors are caught before execution.

**Acceptance Criteria:**
- [ ] Detects invalid JSON syntax with line number
- [ ] Verifies required top-level fields (project, features)
- [ ] Checks that features is an array with at least one item
- [ ] Validates each feature has required fields (id, name, description, priority, tasks)
- [ ] Returns exit code 0 on success, 1 on error
- [ ] Typecheck passes

### US-002: Validate task structure and fields
**Description:** As a developer, I need to verify all tasks have required fields and correct types so the Saci loop can execute them properly.

**Acceptance Criteria:**
- [ ] Verifies each task has required fields (id, title, description, priority, passes, context, acceptance, tests)
- [ ] Validates task IDs are unique across all features
- [ ] Checks task IDs follow format: F[num]-T[num]
- [ ] Validates priority is a number
- [ ] Ensures passes is boolean
- [ ] Verifies acceptance is non-empty array
- [ ] Checks tests.command is present
- [ ] Displays helpful error with task ID and field name
- [ ] Typecheck passes

### US-003: Detect circular dependencies
**Description:** As a developer, I need to detect circular dependencies in the task graph so infinite loops are prevented.

**Acceptance Criteria:**
- [ ] Reuses existing check_dependencies() function from saci.sh
- [ ] Reports the full cycle path (e.g., "F1-T1 -> F1-T2 -> F1-T1")
- [ ] Lists all tasks involved in circular dependencies
- [ ] Suggests how to break the cycle
- [ ] Exits with error code 1 when cycles detected
- [ ] Typecheck passes

### US-004: Validate dependency references
**Description:** As a developer, I need to verify all dependency IDs reference valid tasks so the dependency system works correctly.

**Acceptance Criteria:**
- [ ] Checks that all dependency IDs exist in the PRP
- [ ] Reports tasks with invalid dependency references
- [ ] Shows which dependency ID is missing and from which task
- [ ] Validates dependencyMode is 'all' or 'any' when present
- [ ] Accepts missing dependencies field (backward compatible)
- [ ] Typecheck passes

### US-005: Display validation summary
**Description:** As a developer, I want to see a summary of validation results so I know if my PRP is ready to use.

**Acceptance Criteria:**
- [ ] Shows green checkmarks for passed validations
- [ ] Shows red X for failed validations
- [ ] Displays count of tasks, features, and dependencies
- [ ] Shows warnings for non-critical issues (e.g., missing hints)
- [ ] Provides suggestions for improvements
- [ ] Outputs "✓ PRP is valid and ready to use" when all checks pass
- [ ] Typecheck passes

## Functional Requirements
- FR-1: Command accepts optional PRP file path: `saci validate [file]` (default: prp.json)
- FR-2: Validates JSON syntax and returns clear parse errors with line numbers
- FR-3: Verifies all required fields exist with correct types
- FR-4: Checks task ID uniqueness and format (F[num]-T[num])
- FR-5: Detects circular dependencies using existing check_dependencies() function
- FR-6: Validates all dependency references point to existing tasks
- FR-7: Checks dependencyMode is valid ('all' or 'any') when present
- FR-8: Displays formatted summary with passed/failed checks
- FR-9: Returns exit code 0 on success, 1 on validation failure
- FR-10: Provides suggestions for fixing detected issues

## Non-Goals
- No automatic fixing of PRP issues (manual fix only)
- No validation of test commands (they run during execution)
- No checking if referenced files exist in context.files
- No linting of task descriptions or acceptance criteria text
- No performance benchmarking or complexity analysis

## Technical Considerations
- Reuse existing jq-based functions from saci.sh (get_task_dependencies, check_dependencies)
- Use consistent error message format matching existing Saci commands
- Maintain backward compatibility with PRPs that don't have dependencies
- Add as new case in main command switch (line ~1350 in saci.sh)
- Follow existing color scheme: GREEN for success, RED for errors, YELLOW for warnings

## Success Metrics
- Reduces runtime errors from invalid PRPs to near zero
- Users report feeling confident their PRP is correct before running
- Clear, actionable error messages that users can fix immediately
- Validation completes in under 1 second for typical PRPs (< 20 tasks)

## Open Questions
- Should we validate that context.files paths exist on disk?
- Should we warn about tasks with very long descriptions (> 200 chars)?
- Should we suggest optimal task ordering based on dependencies?
