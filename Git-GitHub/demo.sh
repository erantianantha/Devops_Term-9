#!/usr/bin/env bash
#
# demo.sh — Task 1 and Task 2, run end to end in a throwaway repository.
#
#   bash demo.sh
#
# Everything happens in a fresh repo under the system temp directory, which is
# deleted on exit. Nothing here touches the repository this file lives in --
# a nested .git would be committed as a broken submodule and the files would
# never upload.

set -u

LAB=$(mktemp -d)
trap 'rm -rf "$LAB"' EXIT

step() { printf '\n============================================================\n %s\n============================================================\n' "$*"; }
run()  { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }

cd "$LAB" || exit 1

step "SETUP  a fresh repository"
run "git init -q -b main ."
# Identity is set locally so this cannot depend on, or disturb, a global config.
git config user.name  "Anantha"
git config user.email "anantha@example.invalid"
git config advice.detachedHead false
echo "  repo: $LAB"

printf 'line one\n' > report.txt
run "git add report.txt"
run "git commit -q -m 'Initial commit: add report.txt' && git log --oneline"

# =============================================================================
step "TASK 1  git commit -m  vs  git commit -a -m"
# =============================================================================

echo
echo "Three kinds of change at once, which is what makes the difference visible:"
printf 'line two, appended\n' >> report.txt      # modified, tracked
printf 'brand new file\n'      > appendix.txt    # new, untracked
printf 'to be deleted\n'       > scratch.txt     # will be tracked, then deleted
git add scratch.txt >/dev/null
git commit -q -m 'Add scratch.txt so it can be deleted later'
rm scratch.txt                                    # deleted, tracked

run "git status --short"
cat <<'TXT'

  Reading `git status --short`: the LEFT column is the staging area, the RIGHT
  column is the working directory.

     M report.txt     modified, NOT staged   (space then M)
    ?? appendix.txt   git has never seen this file
     D scratch.txt    deleted, NOT staged
TXT

step "TASK 1 (a)  plain git commit -m, with nothing staged"
run "git commit -m 'attempt with nothing staged'"
run "git log --oneline"
cat <<'TXT'

  Refused, and nothing was recorded. `git commit` only ever looks at the
  staging area, and the staging area is empty. Notice git separates the two
  kinds of change in its own output -- "not staged" and "untracked" are
  different states, and that distinction is the whole of Task 1.
TXT

step "TASK 1 (b)  git commit -a -m"
run "git commit -a -m 'Task 1: -a picks up the modification and the deletion'"
run "git log --oneline"
run "git show --stat --oneline HEAD"
cat <<'TXT'

  Two files went in without a single `git add`:
    report.txt   modified   -> staged and committed
    scratch.txt  deleted    -> staged and committed

  A deletion is a change to a file git is tracking, so -a catches it. You do
  not need `git rm`.
TXT

step "TASK 1 (c)  what -a did NOT do"
run "git status --short"
run "ls"
cat <<'TXT'

  appendix.txt is still untracked and is not in that commit. This is the part
  that catches people out: write a new file, `git commit -a -m 'add feature'`,
  push, and the file is simply not there.

  -a stages changes to files git ALREADY TRACKS. A new file is not tracked
  yet, so there is nothing for -a to notice.
TXT

step "TASK 1 (d)  a new file needs an explicit git add"
run "git add appendix.txt"
run "git commit -q -m 'Task 1: appendix.txt needed an explicit git add' && git show --stat --oneline HEAD"
run "git status --short"
cat <<'TXT'

  "create mode 100644" in that output is git saying it has never seen this
  path before.

  The rule, stated precisely:

    git commit -a   ==  git add -u  then commit     (tracked files only)
                    !=  git add -A                  (which includes new files)

              modified    deleted    new
    -a           yes        yes       NO
    add -u       yes        yes       NO
    add -A       yes        yes       yes
TXT

# =============================================================================
step "TASK 2  cherry-pick"
# =============================================================================

run "git log --oneline"

step "TASK 2 (a)  a branch with three commits"
run "git switch -c hotfix-branch"

printf 'experimental work in progress\n' > wip-one.txt
git add wip-one.txt; git commit -q -m 'branch: work in progress, NOT for main'

printf 'the fix: timeout raised from 5s to 30s\n' > the-fix.txt
git add the-fix.txt; git commit -q -m 'branch: THE FIX that main needs now'

printf 'more experimental work\n' > wip-two.txt
git add wip-two.txt; git commit -q -m 'branch: more work in progress, NOT for main'

run "git log --oneline -4"

step "TASK 2 (b)  identify the one commit"
PICK=$(git log --format='%h %s' | grep 'THE FIX' | cut -d' ' -f1)
echo "  the commit I want is $PICK"
run "git show --stat --oneline $PICK"
echo
echo "  Checking the contents BEFORE picking is the two second habit that stops"
echo "  you copying the wrong hash:"
run "git show $PICK:the-fix.txt"

step "TASK 2 (c)  switch to main first"
run "git switch main"
run "ls"
echo
echo "  none of the branch's files are here. cherry-pick applies to the branch"
echo "  you are standing on, so you switch to the destination and then pick."

step "TASK 2 (d)  the cherry-pick"
run "git cherry-pick $PICK"

step "TASK 2 (e)  verify it three ways"
run "git log --oneline -3"
run "ls"
run "cat the-fix.txt"
echo
echo "  In the log, on disk, and with the right contents. The last one matters:"
echo "  a commit with the wrong content still looks perfect in git log."

step "TASK 2 (f)  what did NOT come with it"
run "ls"
echo
echo "  wip-one.txt and wip-two.txt are absent. A merge would have brought all"
echo "  three commits; cherry-pick brought exactly the one named."

step "TASK 2 (g)  the hash changed"
NEW=$(git log --format='%h' -1)
echo "  original on the branch : $PICK"
echo "  the copy on main       : $NEW"
run "git log --oneline --graph --all"
cat <<'TXT'

  Same message, same change, different hash, and the original is still sitting
  on hotfix-branch untouched.

  A commit's hash covers its content AND its metadata, including its parent.
  The branch commit's parent is the WIP commit; this one's parent is main's
  tip. Different parent, different hash. So cherry-pick does not move a commit
  -- it replays the change as a new one.

  Consequence worth knowing: if hotfix-branch is later merged into main, the
  same change exists as two commits. Usually git works it out; occasionally it
  produces a conflict that looks like it came from nowhere. `-x` (see
  extras.sh) at least leaves a note saying where the duplicate came from.
TXT

step "FINISHED"
echo "  the throwaway repo at $LAB is deleted now."
