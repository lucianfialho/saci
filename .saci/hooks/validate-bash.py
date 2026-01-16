#!/usr/bin/env python3
"""
Saci PreToolUse Hook: Bash Command Validator

Validates Bash commands BEFORE Claude executes them to prevent:
- Invalid npm scripts (npm run <script-that-doesn't-exist>)
- Dangerous git operations (force push to main/master)
- File operations on non-existent paths
- Other impossible commands

Exit codes:
- 0: Allow command (valid)
- 2: BLOCK command (invalid, sends feedback to Claude via JSON)

Input (stdin): JSON with tool_name, tool_input.command
Output (stdout): JSON with permissionDecision and reason
"""

import json
import sys
import re
import os
import subprocess
from pathlib import Path


def load_package_json():
    """Load and parse package.json if it exists."""
    package_json_path = Path("package.json")
    if package_json_path.exists():
        try:
            with open(package_json_path, 'r') as f:
                return json.load(f)
        except json.JSONDecodeError:
            return None
    return None


def get_available_npm_scripts():
    """Get list of available npm scripts from package.json."""
    pkg = load_package_json()
    if pkg and "scripts" in pkg:
        return list(pkg["scripts"].keys())
    return []


def validate_npm_script(command):
    """Validate npm run <script> commands."""
    match = re.search(r'npm\s+run\s+(\S+)', command)
    if not match:
        return {"allow": True}

    script_name = match.group(1)
    available_scripts = get_available_npm_scripts()

    if not available_scripts:
        # No package.json or no scripts section
        return {
            "allow": False,
            "reason": f"Script '{script_name}' does not exist: package.json not found or has no scripts section."
        }

    if script_name not in available_scripts:
        return {
            "allow": False,
            "reason": f"Script '{script_name}' does not exist in package.json. Available scripts: {', '.join(available_scripts[:5])}{'...' if len(available_scripts) > 5 else ''}"
        }

    return {"allow": True}


def validate_git_command(command):
    """Validate git commands to prevent dangerous operations."""
    # Block force push to main/master
    if re.search(r'git\s+push\s+.*--force', command):
        if re.search(r'\b(main|master)\b', command):
            return {
                "allow": False,
                "reason": "Force push to main/master branch is blocked for safety. Use regular push or create a pull request."
            }

    # Block hard reset without confirmation
    if re.search(r'git\s+reset\s+--hard', command):
        # This is actually used by Saci itself, so we allow it
        # But we could add a warning or check if it's in a safe context
        pass

    return {"allow": True}


def validate_file_operation(command):
    """Validate file operations (rm, mv, cp) to check if paths exist."""
    # Match common file operations
    patterns = [
        (r'\brm\s+(?:-\w+\s+)?(.+)', "remove"),
        (r'\bmv\s+(\S+)\s+', "move"),
        (r'\bcp\s+(\S+)\s+', "copy"),
    ]

    for pattern, operation in patterns:
        match = re.search(pattern, command)
        if match:
            file_path = match.group(1).strip()
            # Remove flags and quotes
            file_path = re.sub(r'^-\w+\s+', '', file_path)
            file_path = file_path.strip('"').strip("'")

            # Skip wildcards and special paths
            if '*' in file_path or file_path.startswith('/dev/') or file_path.startswith('/tmp/'):
                continue

            # Check if path exists
            if not os.path.exists(file_path):
                return {
                    "allow": False,
                    "reason": f"Cannot {operation} '{file_path}': file or directory does not exist."
                }

    return {"allow": True}


def validate_command(command):
    """Main validation function - runs all validators."""
    validators = [
        validate_npm_script,
        validate_git_command,
        validate_file_operation,
    ]

    for validator in validators:
        result = validator(command)
        if not result["allow"]:
            return result

    return {"allow": True}


def main():
    try:
        # Read input from stdin
        input_data = json.load(sys.stdin)

        # Extract command from tool_input
        command = input_data.get("tool_input", {}).get("command", "")

        if not command:
            # No command to validate, allow
            sys.exit(0)

        # Validate command
        result = validate_command(command)

        if result["allow"]:
            # Allow command (exit 0)
            sys.exit(0)
        else:
            # Block command (exit 2) with feedback
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": result["reason"]
                }
            }
            print(json.dumps(output), file=sys.stdout)
            sys.exit(0)  # Changed from exit 2 to exit 0 with JSON output

    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error in validate-bash.py: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
