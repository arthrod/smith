#!/usr/bin/env bash
# Smoke test for install.sh — runs in a fake $HOME to verify the installer
# copies skills and bundles project-local assets into the conejo-smith skill,
# WITHOUT modifying ~/.claude/{hooks,settings.json,CLAUDE.md}.
#
# Usage: bash tests/install.smoke.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FAKE_HOME="$(mktemp -d -t smith-smoke.XXXXXX)"
trap 'rm -rf "$FAKE_HOME"' EXIT

export HOME="$FAKE_HOME"
export SMITH_ASSUME_YES=1
export SMITH_SKIP_SCHEDULER=1

echo "=== Running install ==="
bash "$REPO_ROOT/scripts/install.sh" -y

echo
echo "=== Verifying skills ==="
# Counts skills matching smith* (smith-speckit + smith-*) plus conejo-smith.
SMITH_COUNT=$(ls -d "$FAKE_HOME/.claude/skills/smith"* 2>/dev/null | wc -l | tr -d ' ')
[ -d "$FAKE_HOME/.claude/skills/conejo-smith" ] && CONEJO_COUNT=1 || CONEJO_COUNT=0
TOTAL=$((SMITH_COUNT + CONEJO_COUNT))
echo "Skills installed: $TOTAL (smith*: $SMITH_COUNT, conejo-smith: $CONEJO_COUNT)"
[ "$TOTAL" -ge 26 ] || { echo "FAIL: Expected >= 26 skills, got $TOTAL"; exit 1; }
[ -d "$FAKE_HOME/.claude/skills/smith-speckit" ] || { echo "FAIL: smith-speckit not installed"; exit 1; }
[ -d "$FAKE_HOME/.claude/skills/conejo-smith" ] || { echo "FAIL: conejo-smith not installed"; exit 1; }
[ ! -d "$FAKE_HOME/.claude/skills/smith" ] || { echo "FAIL: stale ~/.claude/skills/smith/ should have been removed"; exit 1; }

echo
echo "=== Verifying conejo-smith bundled assets ==="
CONEJO_DIR="$FAKE_HOME/.claude/skills/conejo-smith"
[ -d "$CONEJO_DIR/hooks" ] || { echo "FAIL: $CONEJO_DIR/hooks missing"; exit 1; }
HOOK_COUNT=$(ls "$CONEJO_DIR/hooks/"*.sh 2>/dev/null | wc -l | tr -d ' ')
echo "Bundled hook scripts: $HOOK_COUNT"
[ "$HOOK_COUNT" -ge 7 ] || { echo "FAIL: Expected >= 7 bundled hooks, got $HOOK_COUNT"; exit 1; }
[ -x "$CONEJO_DIR/hooks/grade-response.sh" ] || { echo "FAIL: grade-response.sh not bundled or not executable"; exit 1; }
[ -f "$CONEJO_DIR/hooks/workflow_summary_lib.py" ] || { echo "FAIL: workflow_summary_lib.py not bundled into conejo-smith"; exit 1; }
[ -f "$CONEJO_DIR/hooks/pricing.json" ] || { echo "FAIL: pricing.json not bundled into conejo-smith"; exit 1; }
[ -f "$CONEJO_DIR/settings-fragment.json" ] || { echo "FAIL: settings-fragment.json not bundled"; exit 1; }
[ -f "$CONEJO_DIR/claude-md-template.md" ] || { echo "FAIL: claude-md-template.md not bundled"; exit 1; }
echo "Conejo-smith assets bundled correctly"

echo
echo "=== Verifying ~/.claude/ was NOT polluted ==="
# The new install model deliberately leaves these untouched. If the installer
# ever starts writing to them again, this test catches the regression.
[ ! -d "$FAKE_HOME/.claude/hooks" ] || { echo "FAIL: ~/.claude/hooks should not be created by installer"; exit 1; }
[ ! -f "$FAKE_HOME/.claude/settings.json" ] || { echo "FAIL: ~/.claude/settings.json should not be created by installer"; exit 1; }
[ ! -f "$FAKE_HOME/.claude/CLAUDE.md" ] || { echo "FAIL: ~/.claude/CLAUDE.md should not be created by installer"; exit 1; }
echo "Global Claude config left untouched (correct)"

echo
echo "=== Verifying scheduler ==="
[ -f "$FAKE_HOME/.smith/scheduler/smith-scheduler.sh" ] || { echo "FAIL: scheduler script not installed"; exit 1; }
[ -x "$FAKE_HOME/.smith/scheduler/smith-scheduler.sh" ] || { echo "FAIL: scheduler script not executable"; exit 1; }
echo "Scheduler installed"

echo
echo "=== Running uninstall ==="
bash "$REPO_ROOT/scripts/uninstall.sh" -y

echo
echo "=== Verifying cleanup ==="
REMAINING_SMITH=$(ls -d "$FAKE_HOME/.claude/skills/smith"* 2>/dev/null | wc -l | tr -d ' ' || true)
REMAINING_SMITH="${REMAINING_SMITH:-0}"
REMAINING_CONEJO=0
[ -d "$FAKE_HOME/.claude/skills/conejo-smith" ] && REMAINING_CONEJO=1 || true
TOTAL_REMAINING=$((REMAINING_SMITH + REMAINING_CONEJO))
[ "$TOTAL_REMAINING" -eq 0 ] || { echo "FAIL: $TOTAL_REMAINING skills remain after uninstall"; exit 1; }
echo "Uninstall clean"

echo
echo "=== All smoke tests passed ==="
