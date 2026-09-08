#!/bin/sh
# Stop hook, MAINTAINER shape (goldpath delivery-cycle RFC, D4).
#
# The application-shaped gate builds an app and runs specdrift against its manifest. Neither
# fits: this repository has no manifest — it IS specdrift — and it is small enough that the
# honest gate is the real one. One executable and one test project build and test in seconds,
# so unlike the accelerator this hook does not have to choose which projects to build. It
# builds and tests everything, then checks that the README still describes what was built.
#
# The mutation and licence gates are deliberately NOT here: stryker takes minutes and the
# licence gate needs a restore. Both run in CI, and the skill names them for the turns where
# they are the right check.
INPUT=$(cat)

case "$INPUT" in
  *'"stop_hook_active":true'* | *'"stop_hook_active": true'*) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

CHANGED=$(git status --porcelain -- '*.cs' '*.csproj' '*.props' '*.json' '*.md' '*.sh' '*.py' 2>/dev/null)
[ -z "$CHANGED" ] && exit 0

LOG=$(mktemp)

CODE_CHANGED=$(git status --porcelain -- '*.cs' '*.csproj' '*.props' '*.json' 2>/dev/null)
if [ -n "$CODE_CHANGED" ]; then
  if ! dotnet test specdrift.sln --nologo -v quiet >"$LOG" 2>&1; then
    echo "stop-gate: the suite is red — fix it before ending the turn." >&2
    tail -n 40 "$LOG" >&2
    rm -f "$LOG"
    exit 2
  fi
fi

# The contract check named by cycle.md §6 and CLAUDE.md: prose must still match the engine.
if [ -x scripts/docs-freshness.sh ]; then
  if ! ./scripts/docs-freshness.sh >"$LOG" 2>&1; then
    echo "stop-gate: scripts/docs-freshness.sh is red — the README stopped describing the engine." >&2
    cat "$LOG" >&2
    rm -f "$LOG"
    exit 2
  fi
fi

rm -f "$LOG"
exit 0
