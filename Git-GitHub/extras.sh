#!/usr/bin/env bash
#
# extras.sh — the cases demo.sh does not cover: a cherry-pick that conflicts,
# the three ways out of one, and the flags worth knowing.
#
#   bash extras.sh
#
# Same arrangement as demo.sh: a temp repo, deleted on exit.

set -u
LAB=$(mktemp -d)
trap 'rm -rf "$LAB"' EXIT

step() { printf '\n============================================================\n %s\n============================================================\n' "$*"; }
run()  { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }

cd "$LAB" || exit 1
git init -q -b main .
git config user.name  "Anantha"
git config user.email "anantha@example.invalid"

printf 'timeout = 5\nretries = 1\n' > settings.conf
git add settings.conf; git commit -q -m 'Initial settings.conf'

step "SETUP  the same line edited on two branches"
git switch -q -c feature
printf 'timeout = 30\nretries = 1\n' > settings.conf
git commit -q -a -m 'feature: raise timeout to 30'
FEATURE=$(git rev-parse --short HEAD)

git switch -q main
printf 'timeout = 10\nretries = 1\n' > settings.conf
git commit -q -a -m 'main: raise timeout to 10'

run "git log --oneline --graph --all"
echo
echo "  Line 1 of settings.conf now says something different on each branch."
echo "  Cherry-picking one onto the other cannot be resolved automatically."

step "A cherry-pick that conflicts"
run "git cherry-pick $FEATURE"
run "git status --short"
echo
echo "  UU = Unmerged, changed on Us and on Them. That is a conflict, not an error."
run "cat settings.conf"
cat <<'TXT'

  Reading the markers:
    <<<<<<< HEAD          what the branch you are on already had
    =======               the divider
    >>>>>>> <hash>        what the commit being applied wants

  Nothing is committed and nothing is lost. Git is waiting.
TXT

step "Way out 1: --abort"
run "git cherry-pick --abort"
run "git status --short"
run "cat settings.conf"
echo
echo "  Everything is exactly as it was before the pick started. Knowing this"
echo "  exists is what makes trying a cherry-pick low risk."

step "Way out 2: resolve, then --continue"
run "git cherry-pick $FEATURE"
# Resolving by hand: write the intended result and delete every marker line.
printf 'timeout = 30\nretries = 1\n' > settings.conf
echo
echo "  (edited settings.conf to the value we want, markers deleted)"
run "grep -c '<<<<<<<' settings.conf || true"
run "git add settings.conf"
run "git cherry-pick --continue --no-edit"
run "git log --oneline -3"
run "cat settings.conf"
cat <<'TXT'

  Committing a file with a marker still in it is a genuine classic. Grepping
  for '<<<<<<<' before `git add` costs nothing and catches it every time.
TXT

step "Way out 3: --skip"
git switch -q -c another-feature
printf 'timeout = 30\nretries = 5\n' > settings.conf
git commit -q -a -m 'another: retries to 5'
SKIPME=$(git rev-parse --short HEAD)
git switch -q main
printf 'timeout = 30\nretries = 9\n' > settings.conf
git commit -q -a -m 'main: retries to 9'
run "git cherry-pick $SKIPME"
run "git cherry-pick --skip"
run "git log --oneline -2"
echo
echo "  --skip drops this commit and moves on. It is for a pick that turned"
echo "  out to be unnecessary -- usually because the change is already there."

step "-x, for a traceable duplicate"
git switch -q -c traceable
printf 'note = added on a branch\n' >> settings.conf
git commit -q -a -m 'traceable: add a note'
TRACE=$(git rev-parse --short HEAD)
git switch -q main
run "git cherry-pick -x $TRACE"
run "git log -1 --format='%B'"
echo
echo "  The '(cherry picked from commit ...)' line is added by -x. On any shared"
echo "  branch this is worth doing: six months later, 'why does this change"
echo "  exist twice?' has an answer written into the history."

step "-n, apply without committing"
git switch -q -c staged-only
printf 'flag = experimental\n' >> settings.conf
git commit -q -a -m 'staged-only: add a flag'
NOCOMMIT=$(git rev-parse --short HEAD)
git switch -q main
run "git cherry-pick -n $NOCOMMIT"
run "git status --short"
run "git log --oneline -1"
echo
echo "  The change is staged, no commit was made, and the log is unchanged."
echo "  This is the one to use when the fix needs adjusting for the branch it"
echo "  is landing on."
run "git reset -q --hard HEAD && git status --short"

step "the reference"
cat <<'TXT'
  git cherry-pick <hash>          one commit
  git cherry-pick <a> <b> <c>     several, applied in the order given
  git cherry-pick A..B            a range, EXCLUDING A
  git cherry-pick A^..B           a range, INCLUDING A
  git cherry-pick -x <hash>       record where it came from
  git cherry-pick -n <hash>       apply, do not commit
  git cherry-pick -e <hash>       edit the message while picking

  git cherry-pick --continue      after staging a resolution
  git cherry-pick --abort         undo the whole thing
  git cherry-pick --skip          give up on this one commit

  Ranges in git are exclusive of the start, which is why A..B does not include
  A and A^..B does. Getting that wrong quietly drops one commit.
TXT
