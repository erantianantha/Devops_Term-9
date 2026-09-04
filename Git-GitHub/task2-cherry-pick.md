# Task 2 — `git cherry-pick`

Run in a throwaway repo by [`demo.sh`](demo.sh); the conflict cases come from
[`extras.sh`](extras.sh). Full captures in [`output/`](output/).

## What it does

Takes **one commit** from anywhere in the repository and replays its changes onto the branch you
are standing on, as a **new** commit.

- **merge** brings across everything on the other branch and records that the two joined.
- **rebase** replays a whole series of commits onto a new base.
- **cherry-pick** copies the commits you name. Nothing else comes with them.

The case it exists for: a fix was made on a branch that is not ready to ship, and `main` needs that
fix today.

## The setup

A branch with three commits, deliberately named so it is obvious which one is wanted:

```
$ git log --oneline -4
bcd6616 branch: more work in progress, NOT for main
4bc1036 branch: THE FIX that main needs now
01655ec branch: work in progress, NOT for main
c5a881a Task 1: appendix.txt needed an explicit git add
```

`git switch -c hotfix-branch` created it. (`git checkout -b` is the older spelling of the same
thing; `switch` exists because `checkout` had grown too many unrelated jobs.)

## Step 1 — find the commit, and check it

```
$ git show --stat --oneline 4bc1036
4bc1036 branch: THE FIX that main needs now
 the-fix.txt | 1 +
 1 file changed, 1 insertion(+)

$ git show 4bc1036:the-fix.txt
the fix: timeout raised from 5s to 30s
```

Looking at the contents before picking is the two-second habit that stops you copying the wrong
hash. `4bc1036` is an abbreviation of the full 40-character SHA-1; git accepts any unambiguous
prefix.

## Step 2 — switch to the destination first

```
$ git switch main
$ ls
appendix.txt
report.txt
```

None of the branch's files are here. That is the "before" picture, and without it there is nothing
to compare against afterwards.

Note that switching branches physically rewrote the working directory. Branches are not labels on a
shelf; checking one out changes the files in front of you.

**Cherry-pick applies to the branch you are standing on**, so you switch to the destination and
then pick. Doing it the other way round is the standard first mistake.

## Step 3 — pick

```
$ git cherry-pick 4bc1036
[main ffc8842] branch: THE FIX that main needs now
 Date: Fri Sep 4 23:02:30 2026 +0530
 1 file changed, 1 insertion(+)
 create mode 100644 the-fix.txt
```

That `Date:` line is the **original author date**, carried over. Cherry-pick keeps the original
author and authored-date; the committer and commit-date become you, now.

## Step 4 — verify, three ways

```
$ git log --oneline -3
ffc8842 branch: THE FIX that main needs now
c5a881a Task 1: appendix.txt needed an explicit git add
d49edfd Task 1: -a picks up the modification and the deletion

$ ls
appendix.txt
report.txt
the-fix.txt

$ cat the-fix.txt
the fix: timeout raised from 5s to 30s
```

In the log, on disk, and with the right contents. The third one is the check that matters — a
commit carrying the wrong content looks perfect in `git log`.

## Step 5 — what did not come with it

`wip-one.txt` and `wip-two.txt` are absent. Only the commit I named was copied; a
`git merge hotfix-branch` would have brought all three. That difference is the entire reason
cherry-pick exists.

## Step 6 — the hash is different, and why

```
  original on the branch : 4bc1036
  the copy on main       : ffc8842
```

```
$ git log --oneline --graph --all
* bcd6616 branch: more work in progress, NOT for main
* 4bc1036 branch: THE FIX that main needs now       <- the original, untouched
* 01655ec branch: work in progress, NOT for main
| * ffc8842 branch: THE FIX that main needs now     <- the copy, on main
|/
* c5a881a Task 1: appendix.txt needed an explicit git add
* d49edfd Task 1: -a picks up the modification and the deletion
* 1523a43 Add scratch.txt so it can be deleted later
* 05bbb35 Initial commit: add report.txt
```

Same message, same change, different hash — and the original is still on `hotfix-branch`.

A commit's hash is computed over its content **and** its metadata, including its parent. The branch
commit's parent is `01655ec`; the new commit's parent is `c5a881a` on main. Different parent,
different hash. Cherry-pick does not move a commit, it replays the change as a new one.

**The practical consequence:** if `hotfix-branch` is later merged into `main`, git sees two commits
making the same change. Usually it reconciles them and the duplicate is a no-op. Occasionally you
get a conflict that appears to come from nowhere. That is the argument for `-x` below.

## When it conflicts

The same line changed differently on two branches:

```
$ git cherry-pick 715dad3
Auto-merging settings.conf
CONFLICT (content): Merge conflict in settings.conf
error: could not apply 715dad3... feature: raise timeout to 30
hint: After resolving the conflicts, mark them with
hint: "git add/rm <pathspec>", then run
hint: "git cherry-pick --continue".
hint: You can instead skip this commit with "git cherry-pick --skip".
hint: To abort and get back to the state before "git cherry-pick",
hint: run "git cherry-pick --abort".

$ git status --short
UU settings.conf
```

`UU` = unmerged on our side, unmerged on theirs. Both changed it.

```
$ cat settings.conf
<<<<<<< HEAD
timeout = 10
=======
timeout = 30
>>>>>>> 715dad3 (feature: raise timeout to 30)
retries = 1
```

- `<<<<<<< HEAD` — what the branch you are on already had
- `=======` — the divider
- `>>>>>>> 715dad3` — what the incoming commit wants

Nothing has been committed and nothing is lost. Git is waiting for a decision.

### The three ways out

**`--abort`** — back to exactly where you started:

```
$ git cherry-pick --abort
$ git status --short
(clean)
$ cat settings.conf
timeout = 10
retries = 1
```

Knowing this restores the working tree exactly is what makes attempting a cherry-pick low risk.

**`--continue`** — edit the file to whatever is correct, delete all three marker lines, stage it,
continue:

```
$ grep -c '<<<<<<<' settings.conf
0
$ git add settings.conf
$ git cherry-pick --continue --no-edit
[main f7df29b] feature: raise timeout to 30
```

Committing a file with a marker still in it is a real classic. `grep '<<<<<<<'` before staging costs
nothing.

**`--skip`** — abandon this commit and carry on:

```
$ git cherry-pick --skip
$ git log --oneline -2
5cd1acc main: retries to 9
f7df29b feature: raise timeout to 30
```

For a pick that turned out to be unnecessary, usually because the change is already present.

## `-x` and `-n`

```
$ git cherry-pick -x f0e7419
$ git log -1 --format='%B'
traceable: add a note

(cherry picked from commit f0e7419280b524466dcf5f9e0c99b13506def921)
```

`-x` writes down where the copy came from. On any shared branch it is basic courtesy: it turns
"why does this change exist twice?" into a question with an answer in the history.

```
$ git cherry-pick -n <hash>
$ git status --short
M  settings.conf          <- staged: the M is in the LEFT column
$ git log --oneline -1
(unchanged)
```

`-n` applies the change and stops. Use it when the fix needs adjusting for the branch it is landing
on.

## The variants

```bash
git cherry-pick <hash>          # one commit
git cherry-pick <a> <b> <c>     # several, applied in the order given
git cherry-pick A..B            # a range, EXCLUDING A
git cherry-pick A^..B           # a range, INCLUDING A
git cherry-pick -x <hash>       # record the source in the message
git cherry-pick -n <hash>       # apply without committing
git cherry-pick -e <hash>       # edit the message while picking
```

Ranges in git are exclusive of the start. `A..B` means "after A, through B", so leaving off the `^`
quietly drops one commit — and quietly is the problem.

## Questions this should let me answer

**What is cherry-pick for?** Taking one commit onto the current branch as a new commit. Typically a
hotfix that exists on a branch that is not ready to release.

**Does it move the commit?** No, it copies it. The original stays. The copy has a different hash
because a hash covers the parent, and the parent is different.

**cherry-pick vs merge vs rebase?** Merge brings a whole branch and records the join. Rebase
replays a series onto a new base. Cherry-pick copies only what you name.

**What if it conflicts?** Git stops, marks the file `UU` and writes markers into it. Resolve,
`git add`, `git cherry-pick --continue` — or `--abort` to back out completely.

**Any downside?** The same change now exists in two places. Usually harmless, occasionally the
source of a confusing conflict later. `-x` at least makes it traceable.

**How do I find the commit?** `git log --oneline` to scan, `git log --oneline <branch>` for one
branch, `git log --grep=timeout` to search messages, `git show <hash>` to confirm before picking.
