#!/usr/bin/env python3
"""
Saci Safety Hook - PreToolUse for Bash
Blocks dangerous commands that could harm the project or system.

Exit codes:
  0 = allow command
  2 = block command (stderr shown to Claude as feedback)
"""
import sys
import json
import re

# =============================================================================
# Protected Files - Cannot be deleted or overwritten
# =============================================================================
PROTECTED_FILES = [
    # Environment & secrets
    '.env',
    '.env.local',
    '.env.production',
    '.env.development',
    '.env.staging',
    
    # Git
    '.git',
    '.gitignore',
    '.gitmodules',
    
    # Lock files
    'package-lock.json',
    'yarn.lock',
    'pnpm-lock.yaml',
    'Cargo.lock',
    'go.sum',
    'poetry.lock',
    'Gemfile.lock',
    'composer.lock',
    'Pipfile.lock',
    
    # CI/CD & Config
    '.github',
    '.gitlab-ci.yml',
    '.travis.yml',
    'Dockerfile',
    'docker-compose.yml',
    
    # Saci files
    'prp.json',
    'progress.txt',
]

# =============================================================================
# Dangerous Command Patterns - Always blocked
# =============================================================================
DANGEROUS_PATTERNS = [
    # Destructive file operations
    (r'rm\s+-rf\s+/', "rm -rf on root directory"),
    (r'rm\s+-rf\s+~', "rm -rf on home directory"),
    (r'rm\s+-rf\s+\*', "rm -rf with wildcard"),
    (r'rm\s+-rf\s+\.\s', "rm -rf on current directory"),
    (r'rm\s+-rf\s+\.\.', "rm -rf on parent directory"),
    
    # System destruction
    (r'>\s*/dev/sd', "writing to disk device"),
    (r'mkfs\.', "formatting filesystem"),
    (r'dd\s+if=.*of=/dev', "dd to disk device"),
    (r':\(\)\s*\{\s*:\|:', "fork bomb"),
    (r'chmod\s+-R\s+777\s+/', "chmod 777 on root"),
    (r'chown\s+-R.*\s+/', "chown on root"),
    
    # Dangerous sudo
    (r'sudo\s+rm\s+-rf', "sudo rm -rf"),
    (r'sudo\s+chmod\s+-R\s+777', "sudo chmod 777"),
    (r'sudo\s+dd\s+', "sudo dd"),
]

# =============================================================================
# Git Dangerous Operations
# =============================================================================
GIT_DANGEROUS = [
    (r'git\s+push\s+.*--force', "git push --force can overwrite remote history. Use --force-with-lease instead"),
    (r'git\s+push\s+-f\s+', "git push -f can overwrite remote history. Use --force-with-lease instead"),
    (r'git\s+reset\s+--hard\s+origin/(main|master)', "git reset --hard on main/master branch"),
    (r'git\s+clean\s+-fdx', "git clean -fdx removes all untracked files including ignored ones"),
    (r'git\s+checkout\s+--\s+\.', "git checkout -- . discards all local changes"),
]

# =============================================================================
# Remote Code Execution - Piping to shell
# =============================================================================
REMOTE_EXEC_PATTERNS = [
    (r'curl\s+.*\|\s*(bash|sh|zsh)', "Piping curl to shell is dangerous - download and review first"),
    (r'wget\s+.*\|\s*(bash|sh|zsh)', "Piping wget to shell is dangerous - download and review first"),
    (r'curl\s+.*\|\s*sudo', "Piping curl to sudo is extremely dangerous"),
    (r'wget\s+.*\|\s*sudo', "Piping wget to sudo is extremely dangerous"),
]

# =============================================================================
# Package Manager Dangerous Operations
# =============================================================================
PACKAGE_DANGEROUS = [
    (r'npm\s+publish', "npm publish - are you sure you want to publish this package?"),
    (r'npm\s+unpublish', "npm unpublish can break dependent packages"),
    (r'yarn\s+publish', "yarn publish - are you sure you want to publish?"),
    (r'pip\s+install\s+--user.*http', "Installing pip package from URL"),
    (r'gem\s+push', "gem push - publishing Ruby gem"),
]

# =============================================================================
# Database Dangerous Operations
# =============================================================================
DATABASE_DANGEROUS = [
    (r'DROP\s+DATABASE', "DROP DATABASE is destructive"),
    (r'DROP\s+TABLE', "DROP TABLE is destructive - use with caution"),
    (r'DELETE\s+FROM\s+\w+\s*;', "DELETE without WHERE clause deletes all rows"),
    (r'TRUNCATE\s+TABLE', "TRUNCATE TABLE deletes all data"),
    (r'DROP\s+SCHEMA', "DROP SCHEMA is destructive"),
]

# =============================================================================
# Secrets Exposure
# =============================================================================
SECRETS_PATTERNS = [
    (r'cat\s+.*\.env', "Don't cat .env files - secrets could be exposed in logs"),
    (r'echo\s+.*\$\{?[A-Z_]*KEY', "Don't echo environment variables containing KEY"),
    (r'echo\s+.*\$\{?[A-Z_]*SECRET', "Don't echo environment variables containing SECRET"),
    (r'echo\s+.*\$\{?[A-Z_]*TOKEN', "Don't echo environment variables containing TOKEN"),
    (r'echo\s+.*\$\{?[A-Z_]*PASSWORD', "Don't echo environment variables containing PASSWORD"),
    (r'echo\s+.*\$\{?[A-Z_]*CREDENTIAL', "Don't echo environment variables containing CREDENTIAL"),
    (r'printenv.*(KEY|TOKEN|SECRET|PASSWORD)', "Don't print sensitive environment variables"),
    (r'env\s*\|.*grep.*(KEY|TOKEN|SECRET|PASSWORD)', "Don't grep for secrets in env output"),
    (r'set\s*\|.*grep.*(KEY|TOKEN|SECRET|PASSWORD)', "Don't grep for secrets in set output"),
]

# =============================================================================
# System Config Modifications
# =============================================================================
SYSTEM_CONFIG_PATTERNS = [
    (r'>\s*/etc/', "Writing to /etc/ system config"),
    (r'sudo.*>\s*/etc/', "Sudo writing to /etc/"),
    (r'rm\s+.*\.(bashrc|zshrc|profile)', "Removing shell config file"),
    (r'>\s*~/\.(bashrc|zshrc|profile)', "Overwriting shell config file"),
    (r'crontab\s+-r', "Removing all cron jobs"),
]

# =============================================================================
# Risky Actions on Protected Files
# =============================================================================
RISKY_ACTIONS = ['rm ', 'rm -', '> ', 'truncate ', 'shred ', 'mv ', 'unlink ']


def check_protected_files(command: str) -> tuple[bool, str]:
    """Check if command targets a protected file with a risky action."""
    for protected in PROTECTED_FILES:
        for action in RISKY_ACTIONS:
            if protected in command and action in command:
                return True, f"Cannot modify/delete '{protected}' - this file is protected"
    return False, ""


def check_patterns(command: str, patterns: list) -> tuple[bool, str]:
    """Check if command matches any pattern in the list."""
    for pattern, message in patterns:
        if re.search(pattern, command, re.IGNORECASE):
            return True, message
    return False, ""


def main():
    try:
        input_data = json.load(sys.stdin)
        tool_input = input_data.get('tool_input', {})
        command = tool_input.get('command', '')
        
        if not command:
            sys.exit(0)
        
        # All pattern checks
        checks = [
            ("Dangerous command", DANGEROUS_PATTERNS),
            ("Git operation", GIT_DANGEROUS),
            ("Remote code execution", REMOTE_EXEC_PATTERNS),
            ("Package manager", PACKAGE_DANGEROUS),
            ("Database operation", DATABASE_DANGEROUS),
            ("Secrets exposure", SECRETS_PATTERNS),
            ("System config", SYSTEM_CONFIG_PATTERNS),
        ]
        
        for category, patterns in checks:
            blocked, reason = check_patterns(command, patterns)
            if blocked:
                print(f"🚫 BLOCKED ({category}): {reason}", file=sys.stderr)
                sys.exit(2)
        
        # Check protected files
        blocked, reason = check_protected_files(command)
        if blocked:
            print(f"🚫 BLOCKED (Protected file): {reason}", file=sys.stderr)
            sys.exit(2)
        
        # All checks passed
        sys.exit(0)
        
    except json.JSONDecodeError:
        sys.exit(0)
    except Exception:
        sys.exit(0)


if __name__ == "__main__":
    main()
