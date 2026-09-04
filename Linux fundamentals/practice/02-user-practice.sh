#!/usr/bin/env bash
#
# 02-user-practice.sh — adduser vs useradd, shown by running both and
# comparing what each one left behind.
#
#   sudo bash practice/02-user-practice.sh
#
# This creates two real accounts and deletes them again at the end. Run it on
# a throwaway VM or in a container, not on a machine you care about. Both
# accounts are locked (no password is set), so neither can be logged into.

set -u

RAW=demo-useradd        # created with bare useradd
FULL=demo-useradd-full  # created with useradd plus the options it needs
SCRIPTED=demo-adduser   # created by adduser itself

step() { printf '\n===== %s\n' "$*"; }
run()  { printf '\n$ %s\n' "$*"; eval "$@" 2>&1; }

[ "$(id -u)" -eq 0 ] || { echo "this script needs root: sudo bash $0"; exit 1; }

cleanup() {
    step "cleaning up"
    userdel -r "$RAW"  2>/dev/null && echo "  removed $RAW"
    userdel -r "$FULL" 2>/dev/null && echo "  removed $FULL"
    userdel -r "$SCRIPTED" 2>/dev/null && echo "  removed $SCRIPTED"
}
trap cleanup EXIT

step "what these two commands actually are"
run "which useradd adduser 2>/dev/null"
run "file \$(which adduser) 2>/dev/null | cut -c1-120"
cat <<'TXT'

  useradd is a compiled binary from the shadow-utils package. It is the
  low-level tool: it does exactly what you tell it and nothing more.

  adduser on Debian and Ubuntu is a PERL SCRIPT that calls useradd with
  sensible defaults, then does the extra work -- home directory, skeleton
  files, group, and an interactive password prompt.

  On RHEL and Fedora, `adduser` is a symlink TO useradd, so the two behave
  identically there. That difference is worth knowing before repeating
  "always use adduser" on a distro where it means nothing.
TXT

step "1. bare useradd, with no options at all"
run "useradd $RAW"
run "getent passwd $RAW"
run "id $RAW"
run "ls -la /home/ | grep $RAW || echo '  NO HOME DIRECTORY was created'"
cat <<'TXT'

  Read the passwd entry: the last field is the login shell, and it is
  /bin/sh or empty rather than /bin/bash; the second-to-last is the home
  directory, which is recorded but was never created.

  An account like this can exist for weeks before anyone notices, and the
  symptom when they do is a login that lands in / with no dotfiles.
TXT

step "2. useradd done properly, which is what adduser does for you"
run "useradd --create-home --shell /bin/bash --comment 'Demo account' $FULL"
run "getent passwd $FULL"
run "ls -la /home/$FULL"
echo
echo "  Those dotfiles were copied from /etc/skel:"
run "ls -la /etc/skel"
cat <<'TXT'

  /etc/skel is the template for a new home directory. Anything put there --
  a default .bashrc, a company .vimrc, an SSH config -- is copied into every
  account created afterwards. Accounts made before the change do not get it.
TXT

step "3. adduser itself, run non-interactively"
if command -v adduser >/dev/null 2>&1 && file "$(which adduser)" | grep -qi 'perl\|text'; then
    # --disabled-password skips the password prompt (the account stays locked),
    # --gecos '' skips the full-name/room/phone questions. Without those two
    # flags adduser blocks waiting for input, which is why it needs handling
    # before it can be used in any script.
    run "adduser --disabled-password --gecos '' $SCRIPTED"
    run "getent passwd $SCRIPTED"
    run "ls -A /home/$SCRIPTED"
    echo
    echo "  One command produced everything section 2 needed four options for:"
    echo "  the home directory, the skeleton files, a matching group, and a"
    echo "  bash shell. That is the entire argument for adduser on Debian."
else
    echo "  adduser here is not the Debian/Ubuntu script (it is a link to"
    echo "  useradd, or it is not installed), so there is nothing extra to show."
fi

step "4. what the two accounts look like side by side"
printf '\n  %-14s %-8s %-8s %-22s %s\n' USER UID GID HOME SHELL
for u in "$RAW" "$FULL" "$SCRIPTED"; do
    IFS=: read -r name _ uid gid _ home shell < <(getent passwd "$u")
    printf '  %-14s %-8s %-8s %-22s %s\n' "$name" "$uid" "$gid" "$home" "$shell"
done
echo
for u in "$RAW" "$FULL" "$SCRIPTED"; do
    if [ -d "/home/$u" ]; then
        printf '  /home/%-14s exists, %s entries\n' "$u" "$(ls -A "/home/$u" | wc -l)"
    else
        printf '  /home/%-14s DOES NOT EXIST\n' "$u"
    fi
done

step "5. the files these commands touch"
run "grep -E '^($RAW|$FULL|$SCRIPTED):' /etc/passwd"
run "grep -E '^($RAW|$FULL|$SCRIPTED):' /etc/shadow | cut -d: -f1,2,3"
run "grep -E '^($RAW|$FULL|$SCRIPTED):' /etc/group"
cat <<'TXT'

  /etc/passwd   name:x:uid:gid:comment:home:shell   world-readable. The 'x'
                means "the password hash is in /etc/shadow", which is the
                whole reason /etc/shadow exists.

  /etc/shadow   name:hash:...  root-only. The field shown above is the hash
                field: '!' or '*' means the account is LOCKED -- it exists but
                no password will ever match, which is correct for a service
                account and for both accounts here.

  /etc/group    every user gets a group of the same name by default, so that
                a file created by one user is not readable by unrelated users
                through a shared group.

  /etc/login.defs holds the defaults (UID ranges, password ageing);
  /etc/skel is the home directory template.
TXT

step "6. deleting"
echo "  userdel <user>      removes the account, LEAVES the home directory"
echo "  userdel -r <user>   removes the account AND the home directory"
echo
echo "  Files owned by a deleted user keep the numeric UID, so ls shows a bare"
echo "  number instead of a name -- and the next account created with that UID"
echo "  silently inherits them. That is the argument for -r, or for archiving"
echo "  the home directory before deleting."
