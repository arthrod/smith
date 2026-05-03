#!/usr/bin/env bash
# Smith installer — copies skills, hooks, scheduler, and merges settings into
# your Claude Code config. Idempotent: re-run to upgrade.
#
# Usage:
#   ./scripts/install.sh              # interactive
#   ./scripts/install.sh -y            # assume yes to all prompts
#   curl -fsSL https://raw.githubusercontent.com/arthrod/smith/main/scripts/install.sh | bash
#
# Environment:
#   SMITH_HOME          (default: ~/.smith)        where scheduler + runtime state live
#   CLAUDE_HOME         (default: ~/.claude)       where skills and hooks are installed
#   SMITH_SKIP_SCHEDULER=1                         skip scheduler prompt even on macOS
#   SMITH_ASSUME_YES=1                             same as -y

set -euo pipefail

# ---------- constants ----------
SMITH_REPO_URL="https://github.com/arthrod/smith.git"
SMITH_HOME="${SMITH_HOME:-$HOME/.smith}"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CLAUDE_SKILLS_DIR="$CLAUDE_HOME/skills"
CLAUDE_HOOKS_DIR="$CLAUDE_HOME/hooks"
CLAUDE_SETTINGS="$CLAUDE_HOME/settings.json"
CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"

# ---------- arg parsing ----------
ASSUME_YES="${SMITH_ASSUME_YES:-0}"
for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help)
            sed -n '2,15p' "$0" | sed 's/^# *//'
            exit 0
            ;;
    esac
done

# ---------- helpers ----------
c_reset='\033[0m'; c_bold='\033[1m'; c_green='\033[32m'; c_yellow='\033[33m'; c_red='\033[31m'; c_blue='\033[34m'
info()    { printf "${c_blue}==>${c_reset} %s\n" "$*"; }
ok()      { printf "${c_green}✓${c_reset} %s\n" "$*"; }
warn()    { printf "${c_yellow}!${c_reset} %s\n" "$*" >&2; }
err()     { printf "${c_red}✗${c_reset} %s\n" "$*" >&2; }
prompt_yn() {
    [ "$ASSUME_YES" = "1" ] && return 0
    local msg="$1"; local default="${2:-y}"
    local hint="[Y/n]"; [ "$default" = "n" ] && hint="[y/N]"
    printf "${c_bold}?${c_reset} %s %s " "$msg" "$hint"
    read -r reply </dev/tty || reply=""
    reply="${reply:-$default}"
    [[ "$reply" =~ ^[yY] ]]
}

# ---------- bootstrap: if piped from curl, clone first ----------
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ -z "$SCRIPT_PATH" ] || [ ! -f "$SCRIPT_PATH" ]; then
    info "Bootstrapping Smith installer (no local repo detected)"
    command -v git >/dev/null || { err "git is required to bootstrap. Install git and retry."; exit 1; }
    BOOTSTRAP_DIR="$(mktemp -d -t smith-install.XXXXXX)"
    trap 'rm -rf "$BOOTSTRAP_DIR"' EXIT
    git clone --depth 1 "$SMITH_REPO_URL" "$BOOTSTRAP_DIR/smith" >/dev/null 2>&1 || {
        err "Failed to clone $SMITH_REPO_URL"; exit 1;
    }
    exec bash "$BOOTSTRAP_DIR/smith/scripts/install.sh" "$@"
fi

REPO_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"

# ---------- banner ----------
cat <<'EOF'
   _____ __  __ _____ _______ _    _
  / ____|  \/  |_   _|__   __| |  | |
 | (___ | \  / | | |    | |  | |__| |
  \___ \| |\/| | | |    | |  |  __  |
  ____) | |  | |_| |_   | |  | |  | |
 |_____/|_|  |_|_____|  |_|  |_|  |_|

 Spec-driven development for Claude Code
EOF
echo
info "Installing Smith from: $REPO_ROOT"
info "Claude home:          $CLAUDE_HOME"
info "Smith home:           $SMITH_HOME"
echo

# ---------- platform detection ----------
OS="$(uname -s)"
IS_MACOS=0; IS_LINUX=0
case "$OS" in
    Darwin) IS_MACOS=1 ;;
    Linux)  IS_LINUX=1 ;;
    *) err "Unsupported OS: $OS. Smith supports macOS and Linux."; exit 1 ;;
esac

# ---------- dependency check ----------
info "Checking dependencies"
MISSING_DEPS=()
command -v git >/dev/null || MISSING_DEPS+=("git")
command -v jq  >/dev/null || MISSING_DEPS+=("jq")

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    err "Missing required tools: ${MISSING_DEPS[*]}"
    if [ "$IS_MACOS" = "1" ]; then
        echo "  Install with: brew install ${MISSING_DEPS[*]}"
    else
        echo "  Install with your package manager, e.g. apt install ${MISSING_DEPS[*]}"
    fi
    exit 1
fi
ok "git and jq found"

# Optional tools — warn only
if ! command -v gh >/dev/null 2>&1; then
    warn "gh (GitHub CLI) not found — smith-taskstoissues and some smith-build features will be limited"
fi

# ---------- confirm install ----------
echo
info "Smith will:"
echo "  • Copy 27 skills → $CLAUDE_SKILLS_DIR/{smith-speckit,smith-*,conejo-smith}"
echo "  • Bundle hooks + rubric + settings fragment into the conejo-smith skill"
echo "    as an OFFLINE FALLBACK ($CLAUDE_SKILLS_DIR/conejo-smith/). At runtime,"
echo "    /conejo-smith downloads the latest from github.com/arthrod/smith and"
echo "    only uses this bundle if the network clone fails."
echo "  • Copy scheduler → $SMITH_HOME/scheduler/"
echo
echo "  Notes:"
echo "    – ~/.claude/hooks/ is NOT modified."
echo "    – ~/.claude/settings.json is NOT modified."
echo "    – ~/.claude/CLAUDE.md is NOT modified."
echo "    Project-local installation happens inside each repo via /conejo-smith,"
echo "    which fetches assets from the smith repo at runtime by default."
if [ "$IS_MACOS" = "1" ] && [ "${SMITH_SKIP_SCHEDULER:-0}" != "1" ]; then
    echo "  • Offer to install a macOS LaunchAgent for the daily scheduler"
fi
echo
prompt_yn "Proceed?" y || { info "Aborted by user"; exit 0; }

# ---------- create target dirs ----------
mkdir -p "$CLAUDE_SKILLS_DIR" "$SMITH_HOME/scheduler"

# ---------- copy skills ----------
info "Copying skills"
SKILL_COUNT=0
for skill_src in "$REPO_ROOT"/skills/smith-* "$REPO_ROOT"/skills/conejo-smith; do
    [ -d "$skill_src" ] || continue
    skill_name="$(basename "$skill_src")"
    rm -rf "$CLAUDE_SKILLS_DIR/$skill_name"
    cp -R "$skill_src" "$CLAUDE_SKILLS_DIR/"
    SKILL_COUNT=$((SKILL_COUNT + 1))
done

# Migrate from pre-rename layout: if a stale ~/.claude/skills/smith/ exists from an
# earlier install, remove it so the renamed smith-speckit takes over cleanly.
if [ -d "$CLAUDE_SKILLS_DIR/smith" ]; then
    rm -rf "$CLAUDE_SKILLS_DIR/smith"
    info "Removed stale ~/.claude/skills/smith/ (renamed to smith-speckit)"
fi

ok "Installed $SKILL_COUNT skills"

# ---------- bundle assets into the conejo-smith skill ----------
# The conejo-smith skill copies these INTO each project on demand. They live
# under the skill directory so the skill is self-contained and so re-running
# install.sh keeps them in sync with the smith repo.
CONEJO_SKILL_DIR="$CLAUDE_SKILLS_DIR/conejo-smith"
if [ -d "$CONEJO_SKILL_DIR" ]; then
    info "Bundling project-local assets into $CONEJO_SKILL_DIR"
    mkdir -p "$CONEJO_SKILL_DIR/hooks"
    HOOK_COUNT=0
    for hook_src in "$REPO_ROOT"/hooks/*.sh; do
        [ -f "$hook_src" ] || continue
        cp "$hook_src" "$CONEJO_SKILL_DIR/hooks/$(basename "$hook_src")"
        chmod +x "$CONEJO_SKILL_DIR/hooks/$(basename "$hook_src")"
        HOOK_COUNT=$((HOOK_COUNT + 1))
    done
    # workflow_summary_lib.py is sourced by workflow-summary.sh — bundle it too.
    if [ -f "$REPO_ROOT/hooks/workflow_summary_lib.py" ]; then
        cp "$REPO_ROOT/hooks/workflow_summary_lib.py" "$CONEJO_SKILL_DIR/hooks/"
    fi
    if [ -f "$REPO_ROOT/hooks/pricing.json" ]; then
        cp "$REPO_ROOT/hooks/pricing.json" "$CONEJO_SKILL_DIR/hooks/"
    fi
    cp "$REPO_ROOT/settings/smith-settings-fragment-local.json" \
       "$CONEJO_SKILL_DIR/settings-fragment.json"
    cp "$REPO_ROOT/settings/claude-md-template.md" \
       "$CONEJO_SKILL_DIR/claude-md-template.md"
    ok "Bundled $HOOK_COUNT hooks + settings fragment + rubric into conejo-smith skill"
else
    warn "conejo-smith skill not found at $CONEJO_SKILL_DIR — bundle step skipped"
fi

# ---------- copy scheduler ----------
info "Copying scheduler"
cp "$REPO_ROOT/scheduler/smith-scheduler.sh" "$SMITH_HOME/scheduler/smith-scheduler.sh"
chmod +x "$SMITH_HOME/scheduler/smith-scheduler.sh"
ok "Installed scheduler script"

# ---------- optional: scheduler LaunchAgent ----------
if [ "$IS_MACOS" = "1" ] && [ "${SMITH_SKIP_SCHEDULER:-0}" != "1" ]; then
    echo
    info "Smith can register a macOS LaunchAgent to run the queue processor daily at 2am."
    info "This runs bash scripts on your machine in the background. You can audit the"
    info "script at $SMITH_HOME/scheduler/smith-scheduler.sh before enabling."
    if prompt_yn "Install the daily scheduler LaunchAgent?" n; then
        LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
        PLIST_DEST="$LAUNCH_AGENT_DIR/com.smith.scheduler.plist"
        mkdir -p "$LAUNCH_AGENT_DIR"
        sed "s|__SMITH_HOME__|$SMITH_HOME|g" \
            "$REPO_ROOT/scheduler/com.smith.scheduler.plist.template" > "$PLIST_DEST"
        launchctl unload "$PLIST_DEST" 2>/dev/null || true
        launchctl load "$PLIST_DEST"
        ok "LaunchAgent installed: $PLIST_DEST"
    else
        info "Skipped scheduler install. You can run it later with:"
        echo "    $REPO_ROOT/scripts/install.sh -y"
    fi
fi

# ---------- done ----------
echo
ok "Smith installed successfully"
echo
echo "  Next steps:"
echo "    1. Open Claude Code in any project"
echo "    2. Run /conejo-smith to bootstrap that project. It will fetch the latest"
echo "       hooks + rubric from github.com/arthrod/smith and copy them in locally."
echo "    3. Then /smith-new for features, or /smith-help to see all commands"
echo "    3. Session logs and vault state will be created in <project>/.smith/vault/"
echo
echo "  Docs: https://github.com/arthrod/smith"
echo "  Website: https://smith.attck.com"
echo
