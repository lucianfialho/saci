#!/usr/bin/env python3
"""
Saci PostToolUse Hook: Test Output Classifier

Classifies test errors after Bash command execution to help Claude understand
what type of error occurred and how to fix it.

Error types:
- ENVIRONMENT: missing dependencies, wrong paths, scripts not found
- CODE: syntax errors, type errors, logic bugs, test failures
- TIMEOUT: hanging process, infinite loop
- UNKNOWN: unclassified errors

Exit codes:
- 0: Allow (don't block, just provide classification)
- 2: Block (critical error that should stop execution)

Input (stdin): JSON with tool_response (command output)
Output (stdout): JSON with decision, reason, and hookSpecificOutput
"""

import json
import sys
import re


def classify_error(output):
    """
    Classify error type based on output text.

    Returns: dict with type, reason, suggestion
    """
    output_lower = output.lower()

    # ENVIRONMENT ERRORS - Missing dependencies, scripts, paths
    environment_patterns = [
        (r"npm ERR!.*missing script", "ENVIRONMENT",
         "npm script missing",
         "Check package.json for available scripts. Use 'npm run' to list all scripts."),

        (r"ENOENT:? no such file or directory", "ENVIRONMENT",
         "File or directory not found",
         "Verify the file path exists. Check for typos in the path."),

        (r"(command not found|No such file or directory).*\b(npm|node|npx|yarn)\b", "ENVIRONMENT",
         "Node.js command not found",
         "Ensure Node.js and npm are installed. Check PATH environment variable."),

        (r"Cannot find module", "ENVIRONMENT",
         "Missing Node.js module",
         "Run 'npm install' to install dependencies. Check if module name is correct."),

        (r"MODULE_NOT_FOUND", "ENVIRONMENT",
         "Module not found",
         "Install missing dependency with 'npm install <package-name>'."),

        (r"EACCES.*permission denied", "ENVIRONMENT",
         "Permission denied",
         "Check file permissions. You may need to run with appropriate permissions."),

        (r"Port \d+ is already in use", "ENVIRONMENT",
         "Port already in use",
         "Stop the process using that port or use a different port."),
    ]

    # CODE ERRORS - Syntax, type errors, logic bugs
    code_patterns = [
        (r"SyntaxError:", "CODE",
         "JavaScript/TypeScript syntax error",
         "Fix the syntax error. Check for missing brackets, semicolons, or typos."),

        (r"TypeError:", "CODE",
         "Type error",
         "Check variable types and initialization. Common issue: calling method on undefined/null."),

        (r"ReferenceError:", "CODE",
         "Reference error",
         "Variable is not defined. Check if variable name is correct and in scope."),

        (r"Test (failed|failure)", "CODE",
         "Test failure",
         "Debug the failing test. Check test expectations vs actual behavior."),

        (r"\d+\s+(tests?|specs?|checks?)\s+(failing|failed)", "CODE",
         "Tests failed",
         "Review failing tests. Fix code logic to pass tests."),

        (r"^FAIL\s+", "CODE",
         "Test failure detected",
         "Review the failing tests and fix the code issues."),

        (r"Expected .* but (got|received)", "CODE",
         "Assertion failure",
         "Check test assertions. Actual value doesn't match expected value."),

        (r"ESLint.*error", "CODE",
         "Linting error",
         "Fix code style issues. Run 'npm run lint:fix' if available."),
    ]

    # TIMEOUT ERRORS
    timeout_patterns = [
        (r"(timeout|timed out|ETIMEDOUT)", "TIMEOUT",
         "Operation timed out",
         "Check for infinite loops or hanging operations. Increase timeout if needed."),

        (r"(killed|SIGTERM|SIGKILL)", "TIMEOUT",
         "Process killed",
         "Process was terminated. May be due to timeout or resource limits."),
    ]

    # Check all patterns
    for patterns in [environment_patterns, code_patterns, timeout_patterns]:
        for pattern, error_type, reason, suggestion in patterns:
            if re.search(pattern, output, re.IGNORECASE | re.MULTILINE):
                return {
                    "type": error_type,
                    "reason": reason,
                    "suggestion": suggestion,
                    "matched_pattern": pattern
                }

    # Default: UNKNOWN
    return {
        "type": "UNKNOWN",
        "reason": "Unclassified error",
        "suggestion": "Review the error output carefully to understand the issue."
    }


def extract_error_details(output):
    """Extract specific error details from output."""
    details = {}

    # Extract file and line number
    file_match = re.search(r'(\S+\.(?:ts|js|tsx|jsx)):(\d+):?(\d+)?', output)
    if file_match:
        details["file"] = file_match.group(1)
        details["line"] = file_match.group(2)
        if file_match.group(3):
            details["column"] = file_match.group(3)

    # Extract error message
    error_match = re.search(r'(Error|FAIL|ERR!):(.+?)(?:\n|$)', output, re.MULTILINE)
    if error_match:
        details["message"] = error_match.group(2).strip()

    return details


def main():
    try:
        # Read input from stdin
        input_data = json.load(sys.stdin)

        # Extract tool response (command output)
        tool_response = input_data.get("tool_response", "")

        # Convert to string if needed
        if isinstance(tool_response, dict):
            tool_response = json.dumps(tool_response)
        elif not isinstance(tool_response, str):
            tool_response = str(tool_response)

        if not tool_response or len(tool_response) < 10:
            # No meaningful output, allow
            sys.exit(0)

        # Classify error
        classification = classify_error(tool_response)
        error_details = extract_error_details(tool_response)

        # Build response
        error_type = classification["type"]
        reason = classification["reason"]
        suggestion = classification["suggestion"]

        # Build feedback message
        feedback_parts = [f"Error classified as: {error_type}"]
        feedback_parts.append(f"Reason: {reason}")

        if error_details:
            if "file" in error_details:
                location = f"{error_details['file']}:{error_details['line']}"
                if "column" in error_details:
                    location += f":{error_details['column']}"
                feedback_parts.append(f"Location: {location}")
            if "message" in error_details:
                feedback_parts.append(f"Message: {error_details['message']}")

        feedback_parts.append(f"Suggestion: {suggestion}")

        feedback_message = "\n".join(feedback_parts)

        # Output classification (don't block, just provide info)
        output = {
            "decision": "allow",  # Don't block, just classify
            "reason": feedback_message,
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "errorType": error_type,
                "errorReason": reason,
                "suggestion": suggestion,
                "details": error_details
            }
        }

        print(json.dumps(output), file=sys.stdout)
        sys.exit(0)

    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error in check-test-output.py: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
