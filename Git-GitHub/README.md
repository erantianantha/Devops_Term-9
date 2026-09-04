# Git / GitHub

**Name:** Anantha  **Enrollment Number:** _(fill in)_  **Date:** 4 September 2026

Two tasks: what `-a` does to `git commit`, and cherry-pick. Both were run end to end in a
throwaway repository; every transcript quoted in the task files is from those runs.

| Task | Write-up |
|---|---|
| 1 | [task1-commit-a-vs-m.md](task1-commit-a-vs-m.md) |
| 2 | [task2-cherry-pick.md](task2-cherry-pick.md) |

```
Git-GitHub/
├── README.md
├── task1-commit-a-vs-m.md
├── task2-cherry-pick.md
├── demo.sh                   tasks 1 and 2, start to finish
├── extras.sh                 conflicts, --abort / --continue / --skip, -x, -n
└── output/
    ├── demo-output.txt
    └── extras-output.txt
```

```bash
bash demo.sh   2>&1 | tee output/demo-output.txt
bash extras.sh 2>&1 | tee output/extras-output.txt
```

Both scripts build a fresh repository under the system temp directory and delete it on exit, so
they cannot touch this repo or anyone's global git config — identity is set with `git config` at
repository scope inside the temp repo.

## Task 1 in one screen

```bash
git commit -m "msg"      # commits ONLY what is already staged
git commit -a -m "msg"   # stages changes to TRACKED files first, then commits
```

|  | modified, tracked | deleted, tracked | new, untracked |
|---|---|---|---|
| `git commit -a` | yes | **yes** | **no** |
| `git add -u` | yes | yes | no |
| `git add -A` | yes | yes | yes |

`commit -a` is `git add -u`, not `git add -A`. The deletion column surprises people in one
direction and the new-file column catches them in the other.

From the run:

```
$ git commit -a -m 'Task 1: -a picks up the modification and the deletion'
[main d49edfd] Task 1: -a picks up the modification and the deletion
 2 files changed, 1 insertion(+), 1 deletion(-)
 delete mode 100644 scratch.txt

$ git status --short
?? appendix.txt          <- the new file is still untracked
```

## Task 2 in one screen

Cherry-pick copies one commit onto the branch you are standing on, as a **new** commit.

```
$ git log --oneline --graph --all
* bcd6616 branch: more work in progress, NOT for main
* 4bc1036 branch: THE FIX that main needs now        <- the original, untouched
* 01655ec branch: work in progress, NOT for main
| * ffc8842 branch: THE FIX that main needs now      <- the copy, on main
|/
* c5a881a Task 1: appendix.txt needed an explicit git add
```

Three things that graph shows at once:

1. **Only the named commit came over.** `wip-one.txt` and `wip-two.txt` are not on main. A merge
   would have brought all three.
2. **The hash changed**, `4bc1036` → `ffc8842`. A hash covers the parent, the parent is different,
   so the commit cannot be reused — it is replayed as a new one.
3. **The original is still on the branch.** Nothing moved.

## Notes

- The folder is `Git-GitHub` rather than `git/GitHub` because `/` is not legal in a Windows folder
  name.
- There is no `.git` directory in here on purpose. The demos run in a temp repo; a nested `.git`
  would be treated as a submodule when this folder is pushed, and none of the files would upload.
- The raw captures contain a lot of `LF will be replaced by CRLF` warnings. That is
  `core.autocrlf` on Windows, it is harmless, and I left it out of the quoted excerpts in the task
  files to keep them readable.
