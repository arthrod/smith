# Getting Started with Smith

Smith is a set of Claude Code skills, hooks, and a scheduler that adds structured development workflows to your projects. This guide walks you through installation, first use, and understanding the vault.

---

## Prerequisites

- **Claude Code** v1.0.30 or later (installed and authenticated)
- **macOS** or **Linux** (macOS recommended for scheduler support)
- **bash** 4.0+
- **git** 2.20+
- **jq** 1.6+ (used by the installer and scheduler)

## Installation

Clone the repo and run the installer:

```bash
git clone https://github.com/arthrod/smith.git
cd smith
bash scripts/install.sh
```

The installer will:

1. Copy all 27 skills to `~/.claude/skills/`
2. Bundle 9 hooks + the project-local settings fragment + the CLAUDE.md rubric template into `~/.claude/skills/conejo-smith/` (NOT into `~/.claude/hooks/`)
3. Optionally install the scheduler LaunchAgent (macOS only)

`~/.claude/settings.json` and `~/.claude/CLAUDE.md` are **not modified** by the installer. To start using Smith on a project, open Claude Code in that project and run **`/conejo-smith` first** — it's the new entry point and wires up the project-local hooks and rubric. After it completes, use `/smith-new` for feature work or `/smith-help` to inspect every command.

### Uninstalling

```bash
bash scripts/uninstall.sh
```

This removes all Smith skills, hooks, and scheduler components. Your project vault data (`.smith/`) is not touched.

---

## First Run: Starting a Feature Workflow

Open Claude Code in a project directory. If this is the first time using Smith on this project, run `/conejo-smith` first — it bootstraps project-local hooks, rubric, and SpecKit scaffolding.

Once the project is bootstrapped, start a feature workflow:

```
/smith-new
```

Smith will walk you through the following steps:

1. **Requirements gathering** -- Smith asks conversational questions about what you want to build.
2. **Spec generation** -- A structured specification is written to your project's `.smith/` directory.
3. **Questions gate** -- Smith generates a question file in `specs/questions/` for any decisions that need your input. You review and answer before proceeding.
4. **Planning** -- A plan and task list are generated from the spec.
5. **Autonomous build** -- Smith implements the tasks, commits, and opens a PR.

For a quick test, try describing a small feature: "Add a health check endpoint that returns the app version and uptime."

---

## Understanding the Vault

Every project that uses Smith gets a `.smith/vault/` directory. This is your local project memory:

| Directory | Purpose |
|-----------|---------|
| `sessions/` | One log file per Claude Code session, tracking what was done and which files changed |
| `agents/` | Persistent memory written by sub-agents at the end of their runs |
| `queue/` | Deferred tasks waiting to be processed (manually or by the scheduler) |
| `bank/` | Ideas parked mid-conversation for later processing |
| `ledger/` | Accumulated patterns and lessons learned from past workflows |

You can browse vault contents at any time with `/smith-vault`.

The vault is local-only. Nothing is sent to any external service.

---

## Key Commands

| Command | What it does |
|---------|-------------|
| `/conejo-smith` | Initialize Smith on a new project (project-local hooks + settings + CLAUDE.md + SpecKit) |
| `/smith-speckit` | Legacy SpecKit-only init (formerly `/smith`; no hooks; assumes hooks are wired elsewhere) |
| `/smith-new` | Start a new feature workflow |
| `/smith-bugfix` | Quick autonomous fix for bugs |
| `/smith-debug` | Diagnostic workflow (read-only) |
| `/smith-queue` | Manage deferred tasks |
| `/smith-bank` | Save ideas for later |
| `/smith-help` | Full command reference |

---

## Next Steps

- Read [Architecture](architecture.md) for a system overview.
- Read [Hooks](hooks.md) to understand what runs automatically.
- Read [Security Model](security-model.md) before enabling the scheduler.
- Read [Scheduler](scheduler.md) if you want autonomous overnight processing.
