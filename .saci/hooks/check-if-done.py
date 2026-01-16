#!/usr/bin/env python3
"""
Saci Stop Hook: Prevent Premature Stopping

Prevents Claude from stopping when tests are still failing.
This is a safety net to ensure quality before task completion.

Exit codes:
- 0: Allow stop (tests passing) or Block with JSON output
- 1: Error occurred

Input (stdin): JSON (not used, but required by hook protocol)
Output (stdout): JSON with decision and reason
"""

import json
import sys
import subprocess
import os


def get_test_command():
    """Get test command from package.json or use default."""
    try:
        with open("package.json", 'r') as f:
            pkg = json.load(f)
            scripts = pkg.get("scripts", {})

            # Prefer test script
            if "test" in scripts:
                return "npm test"

            # Fallback to other common test commands
            for script in ["test:unit", "test:all", "jest", "vitest"]:
                if script in scripts:
                    return f"npm run {script}"

    except (FileNotFoundError, json.JSONDecodeError):
        pass

    # Default fallback
    return "npm test"


def run_tests():
    """
    Run test command and return result.

    Returns: dict with success (bool) and output (str)
    """
    test_cmd = get_test_command()

    try:
        # Run test command
        result = subprocess.run(
            test_cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=60  # 1 minute timeout for quick check
        )

        return {
            "success": result.returncode == 0,
            "output": result.stdout + result.stderr,
            "command": test_cmd
        }

    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "output": "Test command timed out after 60 seconds",
            "command": test_cmd
        }
    except Exception as e:
        return {
            "success": False,
            "output": f"Error running tests: {str(e)}",
            "command": test_cmd
        }


def main():
    try:
        # Read input (required by hook protocol, but we don't use it)
        try:
            input_data = json.load(sys.stdin)
        except:
            input_data = {}

        # Check if we're in a project with tests
        if not os.path.exists("package.json"):
            # No package.json, allow stop (not a Node.js project)
            sys.exit(0)

        # Run tests
        test_result = run_tests()

        if test_result["success"]:
            # Tests passing, allow stop
            sys.exit(0)
        else:
            # Tests failing, block stop
            output = {
                "decision": "block",
                "reason": f"Tests are still failing. You must fix all test failures before stopping.\n\nTest command: {test_result['command']}\n\nRun tests yourself to see the failures, then fix the issues."
            }
            print(json.dumps(output), file=sys.stdout)
            sys.exit(0)

    except Exception as e:
        # On error, allow stop (don't block due to hook failure)
        print(f"Warning: Stop hook error: {e}", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
