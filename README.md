[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![27 Skills](https://img.shields.io/badge/skills-27-brightgreen.svg)](skills/)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blueviolet.svg)](https://claude.ai/code)

# Smith

> Spec-driven development for Claude Code — requirements, plans, and tasks that ship as working code.

<!-- asciinema placeholder -->
_Maintained by [@arthrod](https://github.com/arthrod) — fork of `ATTCKDigital/smith` with project-local install via `/conejo-smith`._

---

## What is Smith?

Claude Code is a powerful AI coding assistant, but it has no built-in workflow structure. Developers jump straight from a vague idea to generated code with no specification, no plan, and no audit trail. The result is hard to review, harder to maintain, and impossible to trace back to requirements. When something goes wrong — and it will — there is no record of what was intended, what was decided, or why.

Smith fixes this by adding 27 skills that encode a full development workflow into Claude Code. The pipeline flows from **spec to plan to tasks to implementation to review to ship**. Every step produces a versioned artifact inside a `.specify/` directory in your project. Claude reads the output of each step as input to the next, so context accumulates instead of evaporating. You never have to re-explain what you're building.

The outcome: you talk to Claude about what you want to build, Smith handles the structured process, and you get a merged PR with full traceability from idea to code. Hooks log every session automatically. A scheduler can process queued tasks overnight. Everything runs locally on your machine, nothing phones home, and every artifact is a plain text file you can read, diff, and version-control.

This fork ships `/conejo-smith` — a project-local bootstrap that installs hooks, settings entries, and the CLAUDE.md rubric **only inside the current repo**. Your global `~/.claude/` is never modified.

---

## Getting Started

### Install via the `skills` CLI (skills only)

```bash
npx skills add arthrod/smith
```

This is the fastest path — it copies all 27 Smith skills into `~/.claude/skills/` and nothing else. Use this if you only want the Smith workflow commands.

**To update:** re-run the same command. `npx skills add` is idempotent.

**To verify:** open Claude Code and type `/conejo-smith` — if it autocompletes, you're set.

### Install via the bundled installer (skills + scheduler; hooks bundled into the skill)

```bash
curl -fsSL https://raw.githubusercontent.com/arthrod/smith/main/scripts/install.sh | bash
```

Same as above plus the macOS scheduler LaunchAgent and the project-local hook/template assets bundled into the `conejo-smith` skill directory. **The installer no longer touches `~/.claude/settings.json`, `~/.claude/hooks/`, or `~/.claude/CLAUDE.md`** — those are project-local now and `/conejo-smith` installs them only when you run it inside a repo.

### First run

Open a project and run `/conejo-smith`. It will:

1. Copy hook scripts (currently 9) to `<project>/.claude/hooks/` and merge hook entries into `<project>/.claude/settings.json` (with backup).
2. Drop the global rubric template into `<project>/CLAUDE.md` (with backup).
3. Run the full SpecKit interview — codebase detection, intake doc, constitution, `.specify/` templates, agents, commands.

Then use `/smith-new`, `/smith-build`, `/smith-debug`, etc. as normal.

> **Why `/conejo-smith` and not `/smith-speckit`?** `/smith-speckit` (formerly `/smith`) only does step 3 (SpecKit init) — it assumes hooks were already wired up. `/conejo-smith` does steps 1–3, scoped to the current repo, and then delegates to `/smith-speckit` for the interview. Use `/smith-speckit` directly only if hooks are already wired elsewhere and you just want to refresh the SpecKit scaffolding.

---

## What's Inside

### Skills (27)

| Category | Commands | Description |
|---|---|---|
| Feature workflow | `/smith-new`, `/smith-explore`, `/smith-specify`, `/smith-clarify`, `/smith-plan`, `/smith-tasks`, `/smith-analyze`, `/smith-implement`, `/smith-build`, `/smith-bugfix`, `/smith-checklist`, `/smith-finish` | End-to-end feature development pipeline |
| Debugging and audit | `/smith-debug`, `/smith-audit` | Diagnostic investigation and cross-system audit reporting |
| Knowledge and vault | `/smith-vault`, `/smith-bank`, `/smith-queue`, `/smith-todo`, `/smith-ledger`, `/smith-reflect` | Persistent session logs, idea storage, task queuing, and accumulated learning |
| Reporting | `/smith-report`, `/smith-taskstoissues` | Client-facing reports and GitHub issue generation |
| Meta | `/conejo-smith`, `/smith-speckit`, `/smith-constitution`, `/smith-migrate-specs`, `/smith-help` | Project bootstrap (project-local), legacy SpecKit-only init (formerly `/smith`), governance, reference |

### Hooks (9)

Hooks are no longer installed globally. `/conejo-smith` copies them into `<project>/.claude/hooks/` and merges entries into `<project>/.claude/settings.json` using `${CLAUDE_PROJECT_DIR}` paths.

| Hook | Event | Purpose |
|---|---|---|
| `session-start-logger.sh` | SessionStart | Creates a session log in `.smith/vault/sessions/` |
| `session-end-review.sh` | Stop | Reviews changes made during the session and prompts for spec updates |
| `workflow-summary.sh` | Stop | Appends per-workflow token/cost/duration totals to the session log when a primary workflow completes |
| `grade-response.sh` | Stop | Grades the turn against `<project>/CLAUDE.md` rubric via a Haiku critic; blocks the stop and forces a retry when score < 100 (up to 3 retries) |
| `file-change-logger.sh` | PostToolUse (Write/Edit) | Logs every file change to the active session log |
| `lint-on-save.sh` | PostToolUse (Write/Edit) | Runs the project linter on changed files |
| `task-router.sh` | PreToolUse (Task) | Routes sub-agent tasks during active workflows |
| `subagent-vault-writeback.sh` | SubagentStop | Persists sub-agent findings to the vault |
| `metrics-tracker.sh` | PostToolUse | Tracks tool-use metrics for the active session |

> The previous `security-guard-bash.sh` and `security-guard-files.sh` hooks were removed in this fork — they were too aggressive and blocked legitimate work. Add narrower `permissions.deny` rules in `<project>/.claude/settings.json` if you need similar protection.

### Scheduler

Smith includes a macOS LaunchAgent that runs the queue processor daily at 2:00 AM. It picks up autonomous tasks from `.smith/vault/queue/`, processes them in isolated git worktrees, and writes results back. This lets you queue up low-priority work during the day and have it done by morning. macOS only for now; Linux systemd support is planned.

---

## How It Works

```
idea
  |
  v
/smith-new        Capture the idea, set up project structure
  |
  v
spec.md           Requirements document with acceptance criteria
  |
  v
plan.md           Technical plan: approach, components, risks
  |
  v
tasks.md          Ordered task breakdown with dependencies
  |
  v
/smith-build      Implement tasks, run tests, commit
  |
  v
PR merged         Reviewed, approved, shipped
```

The **vault** (`.smith/vault/`) is the persistent memory layer. It stores:

- **Session logs** — automatic record of every Claude Code session
- **Agent findings** — sub-agent investigation results that survive across sessions
- **Queue** — deferred tasks for autonomous processing
- **Idea bank** — parked ideas to revisit later
- **Ledger** — accumulated lessons learned from past work

**Hooks** fire on every tool use for logging and metrics. They are wired into the project's `.claude/settings.json` by `/conejo-smith` — never globally.

The **scheduler** processes autonomous tasks from the queue overnight using git worktrees so your working tree stays clean.

---

## Installation

### Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/arthrod/smith/main/scripts/install.sh | bash
```

### Manual install

```bash
git clone https://github.com/arthrod/smith.git
cd smith
./scripts/install.sh
```

### What the installer does

The installer is a **one-time global skill install** — skills go to `~/.claude/skills/`, the scheduler goes to `~/.smith/scheduler/`. **Nothing else in `~/.claude/` is touched.**

- Copies all 27 skills to `~/.claude/skills/`
- Bundles hooks, the project-local settings fragment, and the CLAUDE.md rubric template into `~/.claude/skills/conejo-smith/` (assets the skill copies into each project on demand)
- Optionally installs the macOS scheduler LaunchAgent

The installer is idempotent — re-run to update skills.

After installing, run `/conejo-smith` once inside each project to complete **per-project initialization**: copying hooks into `<project>/.claude/hooks/`, merging hook entries into `<project>/.claude/settings.json`, dropping the rubric into `<project>/CLAUDE.md`, and scaffolding the vault, bank, ledger, `.specify/` templates, constitution, and project-specific CLAUDE.md sections.

### Updating

```bash
cd /path/to/smith && git pull && ./scripts/install.sh -y
```

### Uninstalling

```bash
./scripts/uninstall.sh
```

This removes skills, hooks, and the scheduler LaunchAgent. It restores your original `settings.json` from the backup created during install.

---

## Requirements

- **Claude Code** ([claude.ai/code](https://claude.ai/code))
- **macOS or Linux**
- **git**
- **jq** — required for settings.json manipulation during install
- **gh CLI** (optional) — for PR creation and GitHub issue management

---

## Configuration

All configuration is through environment variables. Everything is optional — Smith works out of the box with sensible defaults.

| Variable | Default | Purpose |
|---|---|---|
| `SMITH_HOME` | `~/.smith` | Scheduler and runtime state directory |
| `CLAUDE_HOME` | `~/.claude` | Claude Code config directory |
| `SMITH_SKIP_SCHEDULER` | (unset) | Set to `1` to skip the scheduler prompt during install |
| `SMITH_ASSUME_YES` | (unset) | Set to `1` to auto-accept all install prompts |

---

## Security

Smith runs entirely on your machine. **No telemetry. No phone-home. No external services.**

This fork removed the upstream `security-guard-bash.sh` and `security-guard-files.sh` hooks — they were too strict and blocked legitimate workflow steps. If you want comparable protection, add narrow `permissions.deny` entries in `<project>/.claude/settings.json` (e.g. `"Bash(rm -rf /:*)"`, `"Read(.env)"`).

The scheduler runs bash scripts via macOS `launchd`. You can audit the full script at `scheduler/smith-scheduler.sh` before enabling it.

### Coexistence with a `Bash(rm:*)` deny rule

Some projects add `"Bash(rm:*)"` to the `deny` list of `.claude/settings.json` as a safety rail against accidental deletion. In Claude Code, `deny` supersedes `allow`, so a workflow can't route around the deny rule by whitelisting a narrower `rm` pattern.

To let Smith clean up its per-branch active-workflow markers under that rule, `/smith-speckit` ships a narrow helper at `.specify/scripts/bash/clear-active-workflow.sh`. The helper only unlinks a single file matching `.smith/vault/active-workflows/<safe-branch>.yaml`, never globs, never recurses, and refuses any path that escapes the active-workflows directory. Every Smith workflow skill calls it instead of inline `rm`, and the default project permissions allow-list it explicitly — so the `Bash(rm:*)` deny stays in place and cleanup still works.

See [docs/security-model.md](docs/security-model.md) for a detailed breakdown of the threat model and mitigations.

---

## Troubleshooting

**"jq not found"**
Install jq before running the installer:
```bash
brew install jq        # macOS
apt install jq         # Debian/Ubuntu
```

**Skills not appearing in Claude Code**
Verify the skills directory exists:
```bash
ls ~/.claude/skills/smith-speckit/
ls ~/.claude/skills/conejo-smith/
```
If missing, re-run `./scripts/install.sh`.

**Hooks not firing**
Hooks are project-local in this fork. Check that `<project>/.claude/settings.json` contains hook entries with `${CLAUDE_PROJECT_DIR}` paths. If missing, run `/conejo-smith` in that project to install them. The reference fragment is:
```bash
cat settings/smith-settings-fragment-local.json
```

**Scheduler not running**
```bash
launchctl list | grep smith
```
Review logs at `~/.smith/scheduler/scheduler.log` for errors.

**Vault directories missing**
Run `/conejo-smith` inside the project to run per-project initialization (hooks, settings, CLAUDE.md, vault, bank, ledger, `.specify/` scaffolding). This is required once per project before using other Smith commands. To create just the vault directories manually:
```bash
mkdir -p .smith/vault/{sessions,agents,queue,bank,ledger}
```

---

## Contributing

Issues and bug reports are welcome. Pull requests are by invitation — see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## License

MIT — see [LICENSE](LICENSE).

---

## Credits

Forked and maintained by [@arthrod](https://github.com/arthrod). Originally built by [ATTCK](https://github.com/ATTCKDigital/smith). Inspired by [superpowers](https://github.com/obra/superpowers), [ralph](https://github.com/snarktank/ralph), [claude-mem](https://github.com/thedotmack/claude-mem), and [claude-skills](https://github.com/alirezarezvani/claude-skills).
