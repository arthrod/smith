---
name: conejo-smith
description: Project-local Smith bootstrap. Recommended entry point. Copies hooks, settings.json hook entries, the global CLAUDE.md rubric into the current repo, then delegates to /smith-speckit for the SpecKit interview — all confined to the current repo's .claude/ and project root. Nothing is written to ~/.claude/. Use when the user wants Smith on a project without polluting their global Claude config, or said "set up smith here", "install smith in this repo", "/conejo-smith", or "bootstrap this project with smith".
argument-hint: [--preset flask-react|fastapi-next|cli-python|express-react] [--no-hooks] [--no-claude-md] [--yes]
---

# Conejo-Smith — Project-Local Smith Bootstrap

This is the **recommended entry point** for setting up Smith on a project. The legacy SpecKit-only skill (formerly `/smith`, now renamed to `/smith-speckit`) assumes hooks/settings/global-CLAUDE.md were already wired up by some other means; `conejo-smith` does both jobs in one invocation, **scoped to the current repo only**, and then delegates to `/smith-speckit` for the SpecKit interview.

After running, the user's `~/.claude/` directory is unchanged. Everything Smith needs lives under `<project>/.claude/` and `<project>/CLAUDE.md`.

**Arguments:** $ARGUMENTS

---

## Phase 0 — Pre-flight

### 0.1 Locate skill assets

The skill bundles its own copies of the hook scripts, the project-local settings fragment, and the CLAUDE.md rubric template at install time:

```
~/.claude/skills/conejo-smith/
├── SKILL.md                 (this file)
├── hooks/                   (7 hook scripts + workflow_summary_lib.py + pricing.json)
├── settings-fragment.json   (project-local hook entries; uses ${CLAUDE_PROJECT_DIR})
└── claude-md-template.md    (global rubric to drop at PROJECT/CLAUDE.md)
```

Verify all three asset paths exist. If any are missing, abort with:

> Conejo-Smith assets missing under `~/.claude/skills/conejo-smith/`. Reinstall via `bash scripts/install.sh` from the smith repo (https://github.com/arthrod/smith).

### 0.2 Resolve target directories

- `PROJECT_DIR` = current working directory (the repo to bootstrap into)
- All writes in Phase A go under `$PROJECT_DIR/.claude/` or `$PROJECT_DIR/`
- **Never write outside `$PROJECT_DIR`.** Specifically: do not touch `~/.claude/`, `~/.smith/`, or any ancestor of `$PROJECT_DIR`.

### 0.3 Confirm with the user

Print exactly what will happen, then wait for confirmation (skip the wait if `--yes` is in `$ARGUMENTS`):

```
Conejo-Smith will install everything LOCALLY in this project (~/.claude is NOT touched):

  PROJECT/.claude/hooks/                  7 hook scripts
  PROJECT/.claude/settings.json           created or merged (hooks + permissions)
  PROJECT/CLAUDE.md                       global rubric (existing file backed up)
  PROJECT/.specify/                       constitution + templates + scripts
  PROJECT/.claude/commands/               smith.* slash commands
  PROJECT/.claude/agents/                 review agents (architect, senior-qa, …)
  PROJECT/.smith/vault/                   sessions, agents, queue, bank, ledger
  PROJECT/specs/init-intake.md            permanent record of project answers
  PROJECT/docs/sessions/                  session logs
  PROJECT/.gitignore                      append entries (created if missing)

Proceed? (y/N)
```

Honor `--no-hooks` (skip A.1 + A.2) and `--no-claude-md` (skip A.3).

---

## Phase A — Project-local hook & rubric install

This is the part `/smith-speckit` does NOT do. Run these steps before the SpecKit interview.

### A.1 Copy hooks → `PROJECT/.claude/hooks/`

```bash
mkdir -p .claude/hooks
# Copy everything: .sh scripts, workflow_summary_lib.py (sourced by
# workflow-summary.sh), and pricing.json. The lib MUST travel with the
# scripts so workflow-summary.sh can locate it via SCRIPT_DIR fallback.
cp ~/.claude/skills/conejo-smith/hooks/* .claude/hooks/
chmod +x .claude/hooks/*.sh
```

Skip entirely if `--no-hooks` is set. The hook scripts are pure shell and contain no per-project state, so re-running overwrites in place — no backup needed.

### A.2 Merge hook entries into `PROJECT/.claude/settings.json`

The bundled `settings-fragment.json` uses `${CLAUDE_PROJECT_DIR}/.claude/hooks/...` so hooks resolve to *this* project regardless of cwd inside the repo.

```bash
mkdir -p .claude
FRAGMENT="$HOME/.claude/skills/conejo-smith/settings-fragment.json"

if [ -f .claude/settings.json ]; then
    cp .claude/settings.json ".claude/settings.json.bak-$(date +%Y%m%d-%H%M%S)"
    jq -s '
      .[0] as $existing | .[1] as $fragment |
      $existing * $fragment |
      .hooks = (
        ($existing.hooks // {}) as $eh |
        ($fragment.hooks // {}) as $fh |
        (($eh | to_entries) + ($fh | to_entries))
        | group_by(.key)
        | map({key: .[0].key, value: (map(.value) | add)})
        | from_entries
      )
    ' .claude/settings.json "$FRAGMENT" > .claude/settings.json.tmp
    mv .claude/settings.json.tmp .claude/settings.json
else
    cp "$FRAGMENT" .claude/settings.json
fi
```

Skip entirely if `--no-hooks` is set.

### A.3 Drop global CLAUDE.md rubric

```bash
TEMPLATE="$HOME/.claude/skills/conejo-smith/claude-md-template.md"
if [ -f CLAUDE.md ]; then
    cp CLAUDE.md "CLAUDE.md.bak-$(date +%Y%m%d-%H%M%S)"
fi
cp "$TEMPLATE" CLAUDE.md
```

Skip entirely if `--no-claude-md` is set.

> **Note:** Phase B will append project-specific sections (Project Overview, Tech Stack, Common Commands, etc.) to this file. The rubric template is the *baseline*; Phase B appends, it does not overwrite.

### A.4 Phase A summary

After A.1–A.3, print:

```
Phase A complete:
  ✓ N hook scripts installed in .claude/hooks/        (or "skipped: --no-hooks")
  ✓ .claude/settings.json merged                       (or "skipped: --no-hooks")
  ✓ CLAUDE.md rubric installed (backup: <path>)        (or "skipped: --no-claude-md")
```

---

## Phase B — Full SpecKit interview & scaffolding

Now run the standard SpecKit-init workflow. It lives at the renamed skill:

```
~/.claude/skills/smith-speckit/SKILL.md
```

Read that file directly and execute its **Phase 1 through Phase 5** verbatim, with the adjustments below. Treat its instructions as inlined here.

### Adjustments vs. `/smith-speckit`

1. **Phase 0 (Locate Skill Assets)** in the smith-speckit SKILL.md is already satisfied — the smith-speckit skill assets must exist alongside conejo-smith for Phase B to work. If `~/.claude/skills/smith-speckit/templates/` is missing, abort with the same message smith-speckit would print.

2. **Phase 4.3 (Generate CLAUDE.md)** — `CLAUDE.md` already exists from A.3. Do NOT overwrite. Instead, **append** the project-specific sections (Project Overview, Tech Stack, Architecture, SpecKit Workflow, etc.) below the existing rubric content, separated by a clear `\n\n---\n\n` divider and a `# Project-Specific Configuration` heading.

3. **Phase 4.6 (Create `.claude/settings.json`)** — file already exists from A.2. Do NOT overwrite. Instead, **merge** the framework-specific permissions into the existing `permissions.allow` array using jq, deduplicating. Do NOT touch the `hooks` block. Example:

   ```bash
   ADDITIONS='{"permissions":{"allow":["Bash(npm run:*)","Bash(npm install:*)"]}}'
   jq -s '
     .[0] as $existing | .[1] as $additions |
     $existing
     | .permissions.allow = (
         ((.permissions.allow // []) + ($additions.permissions.allow // []))
         | unique
       )
   ' .claude/settings.json <(echo "$ADDITIONS") > .claude/settings.json.tmp
   mv .claude/settings.json.tmp .claude/settings.json
   ```

4. **Phase 5 (Verification report)** — append a "Project-Local Hooks" section to the report listing the 7 hooks now active in `<project>/.claude/hooks/` and noting that `~/.claude/` was untouched.

Everything else from the smith SKILL.md (codebase detection, intake document, one-question-at-a-time interview, constitution generation, monorepo handling, command/agent copies, `.gitignore` entries) runs unchanged.

---

## Idempotency

Re-running `/conejo-smith`:

- **Phase A.1**: hooks overwritten in place (pure scripts, no project-specific state).
- **Phase A.2**: existing `settings.json` is backed up first, then merged. Hook entries are deduped by key, so re-running does not duplicate them. Pre-existing user permissions/env are preserved.
- **Phase A.3**: existing `CLAUDE.md` is backed up first, then replaced with the rubric. Phase B then re-appends project sections.
- **Phase B**: reads `specs/init-intake.md` if present and uses recorded answers without re-asking. If the user wants to refresh, they edit the intake file or delete it before re-running.

---

## Why this skill exists (vs. `/smith-speckit`)

| Concern | `/smith-speckit` | `/conejo-smith` |
|---|---|---|
| Hooks | Not installed by this skill — assumes you wired them elsewhere | Installed by the skill, only into the current project |
| `~/.claude/settings.json` | Not touched | Never touched |
| Global `~/.claude/CLAUDE.md` rubric | Not touched | Never touched |
| Project-level `CLAUDE.md` | Created by skill | Created by skill (rubric + project sections) |
| `.specify/`, `.claude/commands/`, vault | Created by skill | Created by skill (delegates to `/smith-speckit`) |
| Scope of effect | Per-project SpecKit only | Per-project: hooks + rubric + SpecKit |

Use `/conejo-smith` for any new project. Use `/smith-speckit` directly only when hooks were already wired by some other path and you only need the SpecKit scaffolding refresh.

---

## Important rules (carry over from `/smith-speckit`)

- **Never modify files in the source skill directory** — read from `~/.claude/skills/conejo-smith/` and `~/.claude/skills/smith-speckit/`, write to `$PROJECT_DIR`.
- **Existing files**: always back up before overwriting (`.bak-YYYYMMDD-HHMMSS` suffix).
- **Minimal questions**: skip any intake question where codebase detection has high confidence. Confirm, don't interrogate.
- **One question at a time** during the Phase 3 interactive walkthrough. No batching.
- **Question files before complex changes**: per `~/.claude/CLAUDE.md` Rule 3, Phase B's interview itself satisfies this — the intake doc IS the question file.
