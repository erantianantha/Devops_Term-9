#!/usr/bin/env bash
#
# sysinfo.sh — collect basic facts about this machine, show them, and save a
# report to a directory the user chooses.
#
#   bash sysinfo.sh                 ask where to save
#   bash sysinfo.sh -d myreports    take the directory from the command line
#   bash sysinfo.sh -q              quiet: write the report, print only the path
#
# Everything it creates goes inside one directory, so undoing the whole run is
# a single rm -rf of the folder it names.

set -u

# ---------------------------------------------------------------------------
# variables
# ---------------------------------------------------------------------------
# Collected once, at the top, so every later use is a variable rather than a
# repeated command substitution. Cheaper, and more importantly consistent: if
# the script ran across midnight, two separate `date` calls could disagree.

RUN_DATE=$(date '+%A %d %B %Y, %H:%M:%S %Z')
STAMP=$(date '+%Y%m%d-%H%M%S')      # filename-safe, no spaces or colons
HOSTNAME_NOW=$(hostname)
USERNAME_NOW=$(whoami)
KERNEL=$(uname -sr 2>/dev/null || echo "unknown")
UPTIME_LINE=$(uptime 2>/dev/null | sed 's/^ *//')
# Git Bash on Windows ships an `uptime` that exits 0 and prints nothing, so
# testing the exit status is not enough -- the value itself has to be checked.
[ -z "$UPTIME_LINE" ] && UPTIME_LINE="(not reported by this shell)"

DEFAULT_DIR="sysinfo-report"
TARGET_DIR=""
QUIET=0

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

heading() {
    [ "$QUIET" -eq 1 ] && return 0
    echo
    echo "=============================================================="
    echo "  $1"
    echo "=============================================================="
}

say() { [ "$QUIET" -eq 1 ] || echo "$@"; }

usage() {
    echo "usage: bash sysinfo.sh [-d DIRECTORY] [-q]"
    echo "  -d   where to save the report (skips the prompt)"
    echo "  -q   quiet; print only the path of the report"
    exit 2
}

while getopts ":d:qh" opt; do
    case "$opt" in
        d) TARGET_DIR=$OPTARG ;;
        q) QUIET=1 ;;
        h) usage ;;
        \?) echo "unknown option: -$OPTARG"; usage ;;
        :)  echo "-$OPTARG needs a value"; usage ;;
    esac
done

# ---------------------------------------------------------------------------
# 1. who and where
# ---------------------------------------------------------------------------

heading "1. date, host and user"
say "  date      : $RUN_DATE"
say "  hostname  : $HOSTNAME_NOW"
say "  username  : $USERNAME_NOW"
say "  kernel    : $KERNEL"
say "  uptime    : $UPTIME_LINE"

# ---------------------------------------------------------------------------
# 2. disk
# ---------------------------------------------------------------------------

heading "2. disk usage  (df -h)"
# -h prints 931G instead of 976000000, which is the difference between a number
# you can act on and one you have to divide in your head.
DISK=$(df -h 2>/dev/null)
say "$DISK"

# Pull out the filesystem holding the current directory, and warn if it is
# nearly full -- a report nobody reads is worth less than one line that says
# "you have 2% left".
USED_PCT=$(df -h . 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
if [ -n "${USED_PCT:-}" ] && [ "$USED_PCT" -ge 90 ] 2>/dev/null; then
    say ""
    say "  WARNING: the filesystem holding this directory is ${USED_PCT}% full."
fi

# ---------------------------------------------------------------------------
# 3. processes
# ---------------------------------------------------------------------------

heading "3. running processes"
# ps -ef: -e every process, -f full format (UID, PID, PPID, start time, command).
# ps aux is the BSD spelling and shows %CPU and %MEM instead; on Git Bash for
# Windows only a subset of either is available, which is itself worth knowing.
PROCESSES=$(ps -ef 2>/dev/null || ps 2>/dev/null)
PROC_COUNT=$(printf '%s\n' "$PROCESSES" | tail -n +2 | grep -c .)

say "  $PROC_COUNT processes. The first few:"
say ""
printf '%s\n' "$PROCESSES" | head -6 | sed 's/^/    /' >&2 2>/dev/null
[ "$QUIET" -eq 1 ] || printf '%s\n' "$PROCESSES" | head -6 | sed 's/^/    /'
say "    ..."

# ---------------------------------------------------------------------------
# 4. ask where to save
# ---------------------------------------------------------------------------

heading "4. where should the report go?"

if [ -z "$TARGET_DIR" ]; then
    # -p prints the prompt without a trailing newline. It goes to stderr, so
    # the prompt still appears when stdout is redirected to a file.
    # -r stops backslashes being treated as escapes, which matters the moment
    # somebody types a Windows path.
    read -r -p "  directory name [$DEFAULT_DIR]: " TARGET_DIR

    # If the script is fed from a pipe or a file, read returns empty and the
    # default is used, so it works unattended as well as interactively.
    TARGET_DIR=${TARGET_DIR:-$DEFAULT_DIR}
fi
say "  using: $TARGET_DIR"

# ---------------------------------------------------------------------------
# 5. create the directory and the files
# ---------------------------------------------------------------------------

heading "5. writing the report"

# -p: create parents as needed, and do not fail if it already exists.
mkdir -p "$TARGET_DIR" || { echo "could not create $TARGET_DIR"; exit 1; }
say "  mkdir -p $TARGET_DIR"

REPORT="$TARGET_DIR/system-report-$STAMP.txt"
PROC_FILE="$TARGET_DIR/processes-$STAMP.txt"

# touch creates an empty file (or updates the timestamp of an existing one).
# Not strictly needed -- the redirections below would create both -- but it
# makes the two files exist before anything is written, so a failure halfway
# through still leaves evidence of what was being attempted.
touch "$REPORT" "$PROC_FILE"
say "  touch $(basename "$REPORT")"
say "  touch $(basename "$PROC_FILE")"

# ---------------------------------------------------------------------------
# 6. > and >>
# ---------------------------------------------------------------------------
# > truncates the file and writes. >> appends to whatever is there.
# The report below is built with exactly one > (the first line) and then only
# >>, which is the pattern to use when assembling a file in pieces: one
# deliberate reset at the top, appends after it. Using > twice by accident
# silently throws away everything written before the second one.

echo "SYSTEM REPORT"                                   >  "$REPORT"
echo "generated by sysinfo.sh"                         >> "$REPORT"
echo                                                   >> "$REPORT"
echo "date      : $RUN_DATE"                           >> "$REPORT"
echo "hostname  : $HOSTNAME_NOW"                       >> "$REPORT"
echo "username  : $USERNAME_NOW"                       >> "$REPORT"
echo "kernel    : $KERNEL"                             >> "$REPORT"
echo "uptime    : $UPTIME_LINE"                        >> "$REPORT"
echo "processes : $PROC_COUNT"                         >> "$REPORT"
echo                                                   >> "$REPORT"
echo "DISK USAGE (df -h)"                              >> "$REPORT"
echo "--------------------------------------------"    >> "$REPORT"
printf '%s\n' "$DISK"                                  >> "$REPORT"
echo                                                   >> "$REPORT"
echo "TOP 10 PROCESSES"                                >> "$REPORT"
echo "--------------------------------------------"    >> "$REPORT"
printf '%s\n' "$PROCESSES" | head -10                  >> "$REPORT"

# The full process list gets its own file, written with a single > because it
# is one dump rather than something assembled.
printf '%s\n' "$PROCESSES"                             >  "$PROC_FILE"

say "  wrote $(wc -l < "$REPORT" | tr -d ' ') lines to $REPORT"
say "  wrote $(wc -l < "$PROC_FILE" | tr -d ' ') lines to $PROC_FILE"

# ---------------------------------------------------------------------------
# 7. prove the files exist and have content
# ---------------------------------------------------------------------------

heading "6. what was created"
say "$(ls -l "$TARGET_DIR" | sed 's/^/  /')"

heading "7. the report, read back"
if [ "$QUIET" -eq 1 ]; then
    echo "$REPORT"
else
    sed 's/^/  /' "$REPORT"
fi

heading "done"
say "  report      : $REPORT"
say "  process dump: $PROC_FILE"
say ""
say "  remove everything this run created with:"
say "    rm -rf $TARGET_DIR"
