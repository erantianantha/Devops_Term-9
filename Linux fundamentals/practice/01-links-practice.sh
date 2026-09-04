#!/usr/bin/env bash
#
# 01-links-practice.sh — hard links and symbolic links, from creation to what
# happens when the original is deleted.
#
#   bash practice/01-links-practice.sh
#
# Works entirely inside a temporary directory and removes it at the end, so it
# is safe to run anywhere, including as a normal user.

set -u
LAB=$(mktemp -d)
trap 'rm -rf "$LAB"' EXIT
cd "$LAB" || exit 1

step() { printf '\n== %s\n' "$*"; }
run()  { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }

step "the original file"
printf 'line one\nline two\n' > original.txt
run "ls -li original.txt"
echo
echo "  The first number is the INODE. That number, not the filename, is what"
echo "  the filesystem actually calls this file. A name is just a directory"
echo "  entry pointing at an inode."

step "creating both kinds of link"
run "ln    original.txt hard.txt      # hard link: a second name for the SAME inode"
run "ln -s original.txt soft.txt      # symlink: a small file CONTAINING a path"
run "ls -li"

cat <<'TXT'

  Reading that listing:

    inode      original.txt and hard.txt share one inode number.
               soft.txt has its own, different one.

    link count the second column. It jumped from 1 to 2 the moment the hard
               link was made: two names now refer to that inode.

    type char  the first character of the permissions. '-' is a regular file,
               'l' is a symlink.

    size       the symlink's size is the LENGTH OF THE PATH it stores --
               "original.txt" is 12 characters, so the file is 12 bytes.
TXT

step "they all read the same content"
run "cat original.txt"
run "cat hard.txt"
run "cat soft.txt"

step "writing through the hard link"
run "echo 'line three, written via hard.txt' >> hard.txt"
run "cat original.txt"
echo "  The original changed, because there is only one file. hard.txt is not"
echo "  a copy; it is the same inode under another name."

step "deleting the ORIGINAL name"
run "rm original.txt"
run "ls -li"

step "the hard link still works"
run "cat hard.txt"
echo "  Link count is back to 1. The data was never attached to the name"
echo "  'original.txt' -- it belongs to the inode, and an inode is only freed"
echo "  when its last name is removed and no process still has it open."

step "the symlink is now broken"
run "cat soft.txt"
run "ls -l soft.txt"
run "readlink soft.txt"
run "test -e soft.txt && echo 'target exists' || echo 'test -e says: target does NOT exist'"
run "test -L soft.txt && echo 'test -L says: this IS a symlink (broken or not)'"
cat <<'TXT'

  A dangling symlink. It still holds the text "original.txt"; there is simply
  nothing at that path any more. This is the practical difference:

    hard link  survives deletion of the other name
    symlink    breaks, silently, and `ls` will not tell you unless you look
TXT

step "recreate the target, and the symlink heals"
run "printf 'a brand new file at the old path\n' > original.txt"
run "cat soft.txt"
echo "  Nothing repaired the link. It always was just a path, and the path"
echo "  resolves again."

step "what a hard link cannot do: cross a filesystem"
run "df -h . /tmp 2>/dev/null | head -3"
echo
echo "  A hard link is a directory entry pointing at an inode NUMBER, and inode"
echo "  numbers are only unique within one filesystem. Inode 4823 on /home and"
echo "  inode 4823 on /var are different files, so a directory entry on one"
echo "  filesystem cannot name an inode on another. A symlink stores a path,"
echo "  and paths span everything, which is why it can."
run "ln /etc/hostname ./hostname-hard 2>&1 || true"

step "what a hard link cannot do: point at a directory"
run "mkdir subdir"
run "ln subdir dirlink 2>&1 || true"
cat <<'TXT'

  Refused. Hard-linking a directory would let you build a loop in the tree --
  a directory that contains itself somewhere up its own path. Every tool that
  walks a filesystem (find, du, rm -r, backup software) would recurse forever,
  and there is no way to tell "the real parent" from the loop.

  Symlinks to directories are fine, because a tool can see that it IS a
  symlink and decide not to follow it. That is what find -L versus find does.
TXT
run "ln -s subdir dirsoft && ls -l dirsoft"

step "the ones already on your system"
echo "  These are not exercises; they are how a real Linux install works."
run "ls -l /usr/bin/python3 2>/dev/null || echo '  (not present here)'"
run "ls -l /etc/localtime 2>/dev/null || echo '  (not present here)'"
run "ls -l /bin 2>/dev/null | head -1 || true"
cat <<'TXT'

  /usr/bin/python3 -> python3.12   is how "python3" keeps working across
                                   upgrades: one symlink is repointed.
  /etc/localtime   -> /usr/share/zoneinfo/...  is your timezone. Changing it
                                   is changing where one symlink points.
  /bin             -> usr/bin      is the merged-/usr layout that most
                                   distributions moved to.

  In every case the point is the same: one name, repointed, instead of copying
  files around.
TXT

step "summary"
cat <<'TXT'

                          hard link            symbolic link
  created with            ln target name       ln -s target name
  what it is              another name for     a small file holding a path
                          the same inode
  own inode               no, shares it        yes
  size                    same as the file     length of the stored path
  ls -l type char         -                    l
  target deleted          still works          breaks (dangling)
  cross filesystems       no                   yes
  link to a directory     no                   yes
  target must exist       yes, at creation     no
TXT
