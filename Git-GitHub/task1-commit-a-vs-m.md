# Task 1 — `git commit -a -m` vs `git commit -m`

Every transcript below is from a real run of [`demo.sh`](demo.sh) and [`extras.sh`](extras.sh);
the full captures are in [`output/`](output/).

## The answer

```bash
git commit -m "message"      # commits ONLY what is already in the staging area
git commit -a -m "message"   # stages changes to TRACKED files first, then commits
```

The qualifier "tracked" is the whole task. `-a` is a shortcut for `git add` on files git already
knows about — and only those.

## Why there is a staging area at all

Nothing about `-a` makes sense without this. A change lives in one of three places:

```
  working directory   →   staging area (index)   →   repository
      you edit                 git add                 git commit
```

`git commit` looks at the **staging area** and nowhere else. Edit ten files, forget to `git add`,
and you commit nothing. That is not an oversight in git's design — it is the point. Splitting
"choose what goes in" from "record it" lets one messy afternoon become three focused commits.

`-a` collapses the two steps back into one. Convenient, and it gives up exactly that selectivity.

## The setup: three kinds of change at once

```
$ git status --short
 M report.txt
 D scratch.txt
?? appendix.txt
```

Reading `--short` output: the **left** column is the staging area, the **right** column is the
working directory.

- ` M report.txt` — tracked, modified, **not** staged. The `M` is on the right.
- ` D scratch.txt` — tracked, deleted with a plain `rm`, not staged.
- `?? appendix.txt` — git has never seen this path.

`M ` and ` M` mean different things, and that column position is worth reading carefully.

## Test 1 — plain `git commit -m` with nothing staged

```
$ git commit -m 'attempt with nothing staged'
On branch main
Changes not staged for commit:
  (use "git add/rm <file>..." to update what will be committed)
	modified:   report.txt
	deleted:    scratch.txt

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	appendix.txt

no changes added to commit (use "git add" and/or "git commit -a")

$ git log --oneline
1523a43 Add scratch.txt so it can be deleted later
05bbb35 Initial commit: add report.txt
```

Refused, nothing recorded. Two details worth noticing in git's own output: it puts "not staged" and
"untracked" in separate sections — it is already telling you they are different states — and the
last line names both fixes.

## Test 2 — `git commit -a -m`

```
$ git commit -a -m 'Task 1: -a picks up the modification and the deletion'
[main d49edfd] Task 1: -a picks up the modification and the deletion
 2 files changed, 1 insertion(+), 1 deletion(-)
 delete mode 100644 scratch.txt

$ git show --stat --oneline HEAD
d49edfd Task 1: -a picks up the modification and the deletion
 report.txt  | 1 +
 scratch.txt | 1 -
 2 files changed, 1 insertion(+), 1 deletion(-)
```

Two files, no `git add` at all:

- `report.txt` — modified. Expected.
- `scratch.txt` — **deleted**, and the deletion was staged and committed. A deletion is a change to
  a tracked file, so `-a` catches it. `git rm` is not required.

## Test 3 — what `-a` did not do

```
$ git status --short
?? appendix.txt

$ git show --stat --oneline HEAD
 report.txt  | 1 +
 scratch.txt | 1 -
```

`appendix.txt` is untracked and is not in the commit.

This is the failure mode: write a new file, `git commit -a -m "add the feature"`, push, and the file
is not there. The commit succeeded, the push succeeded, the build fails on someone else's machine,
and nothing anywhere said the word "untracked".

## Test 4 — a new file needs an explicit `git add`

```
$ git add appendix.txt
$ git commit -m 'Task 1: appendix.txt needed an explicit git add'
[main c5a881a] Task 1: appendix.txt needed an explicit git add
 1 file changed, 1 insertion(+)
 create mode 100644 appendix.txt

$ git status --short
(clean)
```

`create mode 100644` is git saying it has never seen this path before — the same signal, from the
other side.

## The rule

> **`-a` stages changes to files git is already tracking.**
> Modified counts. Deleted counts. Brand new does not, because there is nothing to notice yet.

|  | modified | deleted | new |
|---|---|---|---|
| `git commit -a` | yes | yes | **no** |
| `git add -u` | yes | yes | no |
| `git add -A` | yes | yes | yes |
| `git add .` | yes | yes | yes, from the current directory down |

**`commit -a` is `git add -u`, not `git add -A`.**

## Which one to use

Use `-a` for quick work on files that already exist: fixing a typo, tweaking a config value,
iterating. There is nothing to get wrong.

Use `git add` and then `git commit` when:

- **You created files.** `-a` skips them silently.
- **You want more than one commit out of this work.** Stage part, commit, stage the rest, commit
  again. `-a` is all or nothing.
- **You want to look before you commit.** `git diff --staged` shows exactly what is about to go in.
- **You touched something you do not want committed** — a debug print, a local config change, a
  temporary file. `-a` sweeps it in without asking, and that is the strongest argument for the
  longer form.

The habit that makes the choice for you: run `git status` before every commit. Two seconds, and it
tells you which of the two commands you actually want.

## Questions this should let me answer

**What is the difference?** `-m` commits what is staged. `-a` stages tracked changes first. `-a`
does not stage new files — it is `git add -u`, not `git add -A`.

**My new file is missing from the commit. Why?** It was untracked. `-a` only stages files git
already knows about. `git add <file>` first.

**Does `-a` handle deletions?** Yes. Deleting a tracked file is a change to a tracked file. No
`git rm` needed.

**Why does the staging area exist?** So you can commit a subset of your changes and split messy
work into clean commits. `-a` deliberately bypasses it.

**How do I see what is about to be committed?** `git diff --staged` for staged, `git diff` for
unstaged, `git status` for the summary of both.
