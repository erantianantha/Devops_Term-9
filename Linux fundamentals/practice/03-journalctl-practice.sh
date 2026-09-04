#!/usr/bin/env bash
#
# 03-journalctl-practice.sh — read-only tour of the systemd journal.
#
#   bash practice/03-journalctl-practice.sh        # your own user's entries
#   sudo bash practice/03-journalctl-practice.sh   # the whole journal
#
# Every command here only READS. Nothing is deleted, rotated or configured.
# If systemd is not running, the script says so and stops rather than printing
# a page of "command not found".

set -u

step() { printf '\n===== %s\n' "$*"; }
run()  { printf '\n$ %s\n' "$*"; eval "$@" 2>&1 | head -12; }

step "is there a journal to read?"
if ! command -v journalctl >/dev/null 2>&1; then
    cat <<'TXT'
  journalctl is not installed.

  That is expected in a container: journald is part of systemd, and a
  container normally runs one application as PID 1 instead of an init
  system. Container logs go to stdout/stderr and are collected by the
  container runtime -- `docker logs <name>` is the equivalent command.

  To run this section for real you need a machine with systemd as PID 1:
  a VM, a cloud instance, or `wsl --install -d Ubuntu` on Windows.
TXT
    exit 0
fi

if ! pidof systemd >/dev/null 2>&1 && [ ! -d /run/systemd/system ]; then
    echo "  journalctl exists but systemd is not PID 1 here, so the journal is"
    echo "  empty. Same conclusion as above."
    exit 0
fi

step "what the journal is"
cat <<'TXT'
  Traditional syslog wrote plain text to /var/log/*.log. The systemd journal
  is a structured, indexed BINARY store: every entry carries fields (unit,
  PID, UID, priority, boot ID, timestamp) rather than being one line of text.

  That is why you cannot `cat` it, and why journalctl can answer questions
  like "errors from this unit, since yesterday, from the previous boot"
  without any grep at all.
TXT

step "the most recent entries"
run "journalctl -n 10 --no-pager"

step "follow live, the equivalent of tail -f"
echo '$ journalctl -f          # not run here: it never exits'

step "one service"
UNIT=$(systemctl list-units --type=service --state=running --no-legend --plain 2>/dev/null | awk 'NR==1{print $1}')
UNIT=${UNIT:-ssh.service}
echo "  picking a unit that actually exists on this machine: $UNIT"
run "journalctl -u $UNIT -n 10 --no-pager"

step "by time"
run "journalctl --since '1 hour ago' --no-pager -n 5"
run "journalctl --since today --until now --no-pager -n 3"
echo
echo "  --since and --until take '2026-09-04 10:00', 'yesterday', '-2h', and"
echo "  most other phrasings you would try."

step "by boot"
run "journalctl --list-boots --no-pager | tail -5"
echo "  -b       this boot"
echo "  -b -1    the previous boot -- the one that matters after a crash,"
echo "           because the logs explaining it are in the boot BEFORE the"
echo "           machine came back."

step "by priority"
run "journalctl -p err -b --no-pager -n 10"
echo
echo "  Priorities, lowest number first: emerg 0, alert 1, crit 2, err 3,"
echo "  warning 4, notice 5, info 6, debug 7. '-p err' means 3 and below,"
echo "  so it includes crit, alert and emerg."

step "structured output"
run "journalctl -n 1 -o json-pretty --no-pager"
echo "  Every entry is a set of fields. -o json makes that visible and makes"
echo "  the journal machine-readable without parsing text."

step "how much space it uses"
run "journalctl --disk-usage"
echo
echo "  Retention is set in /etc/systemd/journald.conf (SystemMaxUse,"
echo "  MaxRetentionSec). Cleaning up is 'journalctl --vacuum-time=7d' or"
echo "  '--vacuum-size=200M' -- both are WRITE operations, so neither is run"
echo "  by this script."
