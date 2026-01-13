#!/usr/bin/env python3
import sys
import json
import subprocess
import os

# Saci Linter Hook
# Runs ESLint on modified files and reports errors back to Claude immediately.

def main():
    try:
        # Read input from stdin
        input_data = json.load(sys.stdin)
        
        # Extract file path from tool input
        tool_input = input_data.get('tool_input', {})
        file_path = tool_input.get('file_path')
        
        if not file_path:
            sys.exit(0)
            
        # Check if file exists and is JS/TS
        if not os.path.exists(file_path):
            sys.exit(0)
            
        if not (file_path.endswith('.js') or file_path.endswith('.ts') or file_path.endswith('.jsx') or file_path.endswith('.tsx')):
            sys.exit(0)
            
        # Run ESLint
        # We use npx eslint with json output format to easily parse it, but for now raw output is enough context
        # We suppress stderr to avoid crashing the hook on config errors
        result = subprocess.run(
            ['npx', 'eslint', '--no-error-on-unmatched-pattern', file_path],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            # Linting failed! 
            # We return structued output to inform Claude
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": f"⚠️ LINTING ERRORS DETECTED in {file_path}:\n\n{result.stdout}\n\nPlease fix these lint errors immediately."
                }
            }
            print(json.dumps(output))
        else:
            # All good, silent exit
            pass
            
    except Exception as e:
        # Failsafe
        sys.exit(0)

if __name__ == "__main__":
    main()
