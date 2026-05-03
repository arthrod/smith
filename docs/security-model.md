# Security Model

Smith is designed with a local-first, deny-by-default security posture. This document covers what Smith can and cannot do, how its security guards work, and what you should audit before enabling autonomous features.

---

## Local-Only Execution

Smith runs entirely on your machine. There is no telemetry, no phone-home, no analytics, and no external API calls made by Smith itself. All vault data, session logs, and scheduler output stay in your local filesystem.

The only network activity comes from Claude Code itself (communicating with the Anthropic API), which is governed by your Claude Code configuration and authentication, not by Smith.

---

## Hook Security

Hooks are bash scripts that Claude Code executes automatically at specific lifecycle events. Each hook is registered in **`<project>/.claude/settings.json`** (project-local — `~/.claude/settings.json` is not modified by `/conejo-smith` or `scripts/install.sh`) and runs with your user permissions.

### What hooks can access

- The current working directory and its contents
- Environment variables available to your shell
- The `.smith/vault/` directory in the current project
- Standard CLI tools (git, jq, bash builtins)

### What hooks cannot do

- Hooks cannot escalate privileges beyond your user account
- Hooks do not have network access beyond what your shell provides
- Hooks cannot modify Claude Code's own configuration at runtime

### Hook event types

| Event | When it fires | Hooks using it |
|-------|--------------|----------------|
| SessionStart | Claude Code session begins | session-start-logger |
| Stop | Claude Code session ends | session-end-review, workflow-summary, grade-response |
| PreToolUse | Before Claude executes a tool call | task-router |
| PostToolUse | After Claude executes a tool call | file-change-logger, lint-on-save, metrics-tracker |
| SubagentStop | When a sub-agent completes | subagent-vault-writeback |

See [Hooks Reference](hooks.md) for full details on each hook.

---

## Security Guards (removed in this fork)

The upstream `security-guard-bash.sh` and `security-guard-files.sh` hooks have been **removed**. They were too aggressive — blocking legitimate dev work like writing config files, reading env vars during debugging, or removing test fixtures.

If you want comparable protection, use Claude Code's native `permissions.deny` rules in `<project>/.claude/settings.json`. They are narrower, scoped to the project, and visible to the user before tool execution. Examples:

```json
{
  "permissions": {
    "deny": [
      "Bash(rm -rf /:*)",
      "Bash(rm -rf ~:*)",
      "Bash(env:*)",
      "Read(.env)",
      "Read(.env.*)",
      "Read(*.pem)",
      "Read(*.key)",
      "Read(~/.ssh/**)",
      "Write(.env)",
      "Write(.env.*)"
    ]
  }
}
```

`deny` supersedes `allow` and is enforced by Claude Code itself, not by a hook script.

---

## Scheduler Security

The scheduler (`~/.smith/scheduler/smith-scheduler.sh`) enables autonomous overnight processing of queued tasks. Because it runs without user interaction, it has additional constraints:

- **Runs as your user** -- The scheduler is a macOS LaunchAgent, running under your account with your permissions. It does not require or use root access.
- **Only processes autonomous tasks** -- The scheduler only picks up tasks in the vault queue that are explicitly marked with `"mode": "autonomous"`. Interactive or untagged tasks are skipped.
- **Git worktree isolation** -- Each task runs in a fresh git worktree, not in your working directory. This prevents autonomous work from conflicting with your in-progress changes.
- **Non-interactive Claude** -- The scheduler invokes Claude Code with the `-p` flag (non-interactive mode). Claude cannot prompt for input; if it encounters ambiguity, the task fails rather than guessing.
- **Scoped to registered projects** -- The scheduler only processes projects listed in `~/.smith/scheduler/projects.json`. It does not scan your filesystem.

---

## What to Audit Before Enabling

Before enabling the scheduler, review:

1. **`<project>/.claude/settings.json`** — confirm any `permissions.deny` rules you added cover the commands and files you consider dangerous in this project.

2. **`~/.smith/scheduler/smith-scheduler.sh`** — review the task selection logic and worktree creation. Confirm you are comfortable with the scheduler creating branches and worktrees in your registered projects.

---

## Reporting Vulnerabilities

If you discover a security vulnerability in this fork, do not open a public issue. Instead, email **arthursrodrigues@gmail.com** with a description of the vulnerability, steps to reproduce, and any relevant log output. See [SECURITY.md](../SECURITY.md) for the full disclosure policy.
