# Linux fundamentals homework

Soft/hard links, `adduser` vs `useradd`, `journalctl`, and a command cheat sheet. All three practice
scripts were run for real on Ubuntu 24.04; the captured runs are in `output/`.

```
Linux fundamentals/
├── README.md
├── practice/
│   ├── 01-links-practice.sh          link lifecycle, safe anywhere
│   ├── 02-user-practice.sh           creates real users, needs root
│   └── 03-journalctl-practice.sh     read-only journal queries
└── output/
    ├── 01-links-practice-output.txt      full run
    ├── 02-user-practice-output.txt       full run + the two steps stdin ate
    └── 03-journalctl-practice-output.txt full run, systemd container
```

## The four tasks

1. **Soft links vs hard links** — what each one is, how to create them, what happens to each when
   the target is deleted, and why hard links can't cross filesystems or point at directories.
2. **adduser vs useradd** — the difference, which one Ubuntu recommends and why, and creating a
   test user the recommended way.
3. **journalctl** — what the systemd journal is and how to read logs for one service.
4. **Command cheat sheet** — the Linux commands you should be able to use without thinking,
   grouped by what you're doing.

## Commands

```bash
cd "Linux fundamentals"
bash      practice/01-links-practice.sh
sudo bash practice/02-user-practice.sh
sudo bash practice/03-journalctl-practice.sh
```

Capture a run: `bash practice/01-links-practice.sh 2>&1 | tee output/01-links-practice-output.txt`

| Script | Safety | Needs |
|---|---|---|
| `01-links-practice.sh` | works in its own temp dir and cleans up after itself | nothing |
| `02-user-practice.sh` | creates real users; prompts before every step, offers to delete them | root, a throwaway VM |
| `03-journalctl-practice.sh` | read-only, only queries logs | systemd; sudo for the full journal |

### How I actually ran it

This is a Windows 11 box. Git Bash isn't Linux and the only WSL distro installed is Docker Desktop's
own `docker-desktop`, which has no systemd. So everything went into throwaway containers.

Stock `ubuntu:24.04` is smaller than the docs assume — no `adduser`, no `file`, no `perl` — so tasks 1
and 2 got a small baked image:

```dockerfile
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y adduser file sudo passwd perl && rm -rf /var/lib/apt/lists/*
```

```bash
docker build -t linuxlab:24.04 .
docker run --rm   -v "$PWD/practice:/lab:ro" linuxlab:24.04 bash /lab/01-links-practice.sh
docker run --rm -i -v "$PWD/practice:/lab:ro" linuxlab:24.04 bash /lab/02-user-practice.sh
```

Task 3 needs a real init, so a second image runs `systemd` as PID 1:

```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y systemd systemd-sysv dbus cron rsyslog
RUN mkdir -p /var/log/journal          # otherwise the journal is tmpfs-only
CMD ["/sbin/init"]
```

```bash
docker run -d --name sdlab --privileged --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw -t sdlab:24.04
docker exec sdlab systemctl is-system-running     # -> running
```

`--privileged --cgroupns=host` plus the cgroup mount is what makes systemd come up inside a container.
It booted in 462 ms and `journalctl` worked normally. All containers were `--rm` or deleted afterwards,
which is why a test password sits in the output in plain sight.

---

## Task 1 — soft links vs hard links

A **hard link** is another name for the same inode. A file's data and metadata live in the inode; a
directory entry is just a name pointing at an inode number. `ln a b` adds a second name pointing at the
same inode and bumps that inode's link count to 2. There is no "original" and no "copy" — the two names
are equal, and the data lives until the last name goes away.

A **soft link** (symlink) is its own small file with its own inode, whose contents are a *path string*.
Opening it makes the kernel read that string and restart the lookup from there. It knows nothing about
inodes, which is why it can cross filesystems and point at directories — and why it breaks the moment
that path stops resolving.

### Creating them

```bash
echo "hello from the original file" > original.txt
ln    original.txt hard.txt      # hard link — another name for the same inode
ln -s original.txt soft.txt      # soft link — a file containing the path "original.txt"
```

### Seeing the difference

From my run (`output/01-links-practice-output.txt`, `ls -li`):

```
178374 -rw-r--r-- 2 root root 29 Sep  4 17:55 hard.txt
178374 -rw-r--r-- 2 root root 29 Sep  4 17:55 original.txt
178389 lrwxrwxrwx 1 root root 12 Sep  4 17:55 soft.txt -> original.txt
```

Three columns carry the whole lesson:

- **Inode (first column).** `hard.txt` and `original.txt` are both `178374` — one file, two names.
  `soft.txt` is `178389`, a genuinely different file.
- **Link count (the number right after the permissions).** `2` for the shared inode, `1` for the
  symlink. That count is what `rm` decrements; the data blocks are freed when it reaches 0.
- **Type char and size.** `-` vs `l`. And `soft.txt` is 12 bytes — exactly the length of the string
  `original.txt`. The symlink literally *is* the path.

`stat` says the same without the squinting:

```
name=original.txt inode=178374 links=2 size=58
name=hard.txt     inode=178374 links=2 size=58
name=soft.txt     inode=178389 links=1 size=12
```

Size is 58 here and 29 in the `ls` above because in between, the script appended a line *through
`hard.txt`* — and `original.txt` grew too. One set of data blocks, two doors into it.

To find every name for one file: `find . -samefile original.txt` printed both `./hard.txt` and
`./original.txt`.

### Deleting the target

`rm original.txt`, then:

```
--- cat hard.txt (expect: still works) ---
hello from the original file
a line appended via hard.txt

--- cat soft.txt (expect: No such file or directory) ---
cat: soft.txt: No such file or directory
```

The hard link is fine and its link count dropped 2 → 1. Nothing was deleted in any real sense; one name
was removed from a directory. The symlink is now dangling — the path it stores no longer resolves.
`find . -xtype l` is how you hunt those; it printed `./soft.txt`.

The follow-up is what makes symlinks click. Create a *brand new, unrelated* file at the same path and
the symlink starts working again:

```
$ echo "brand new file, same name" > original.txt
$ cat soft.txt
brand new file, same name
```

It never pointed at the old data. It pointed at a name.

### Rules and limits

| | hard link | soft link |
|---|---|---|
| Own inode | no — shares the target's | yes |
| Can cross filesystems | no | yes |
| Can link a directory | no | yes |
| Survives deleting the target | yes, it *is* the file | no, goes dangling |
| Size in `ls -l` | the file's size | length of the stored path (12 bytes here) |
| `ls -l` type char | `-` | `l` |
| Bumps the target's link count | yes | no |
| Finding broken ones | can't break | `find -xtype l` |

**Why can't a hard link cross a filesystem?** A directory entry stores an inode *number*, and inode
numbers are only unique within one filesystem. Inode 178374 on `/home` and inode 178374 on `/mnt/data`
are unrelated files. There is nowhere in the on-disk directory format to record "inode 178374, but on
that other device", so the kernel refuses with `EXDEV`. A symlink stores a path, which is global, so it
doesn't care.

**Why no hard links to directories?** Two reasons. The tree stops being a tree — you could build a cycle
(`ln /a /a/b/c`) and anything walking the filesystem (`find`, `rm -r`, a backup) would loop forever with
no way to detect it. And `..` becomes ambiguous: a directory's `..` is a single inode number, so a
directory with two parents can only point back at one. The kernel just says no:

```
$ ln somedir hardlink-to-dir
ln: somedir: hard link not allowed for directory
```

`ln -s somedir softlink-to-dir` is allowed, and is what you actually wanted.

### Where these show up

- `/usr/bin/python3` → `python3.12`. The whole point of symlinks: the version moves, the name people
  type doesn't.
- `/etc/localtime` → `/usr/share/zoneinfo/...`. Change timezone, re-point one link.
- `/etc/alternatives/*` — Debian's entire "which java/editor/pager is the default" system is a
  directory of symlinks.
- `/proc/<pid>/exe`, `/proc/self/fd/1` — magic symlinks the kernel synthesises.
- Hard links are what `cp -l` and rsync's `--link-dest` use for deduplicated backup snapshots: ten
  nightly snapshots, one copy of each unchanged file, ten names for it.

---

## Task 2 — adduser vs useradd

`useradd` is the low-level binary from the `shadow` package. It does exactly what you tell it and
nothing more. `adduser` on Debian/Ubuntu is a Perl wrapper *around* `useradd` that adds the policy you
almost always want: pick the next UID, create the group, create and populate the home directory from
`/etc/skel`, set the shell, and run `passwd` so the account can actually be used.

```
$ file $(which adduser)
/usr/sbin/adduser: Perl script text executable
```

Perl script = the Debian/Ubuntu wrapper. On RHEL-family distros `adduser` is just a **symlink to
`useradd`**, so you get none of that behaviour and the muscle memory silently does something else.
That's the portability trap.

Versions: Ubuntu 24.04.4 LTS, `adduser` 3.137ubuntu1, `passwd` 1:4.13+dfsg1-4ubuntu3.2.

### The three ways, side by side

**1. Bare `useradd u_bare` — the classic gotcha:**

```
$ getent passwd u_bare
u_bare:x:1001:1001::/home/u_bare:/bin/sh
$ ls -ld /home/u_bare
ls: cannot access '/home/u_bare': No such file or directory
$ grep '^u_bare:' /etc/shadow | cut -d: -f1,2
u_bare:!
```

The passwd line *claims* a home at `/home/u_bare`, but the directory was never created. No password
(`!` = locked). Shell is `/bin/sh` because that's what `/etc/default/useradd` says. The account exists
and is unusable.

**2. `useradd` with flags — what you'd write in a script or Dockerfile:**

```
$ useradd -m -s /bin/bash -c "Scripted User" u_flags
$ getent passwd u_flags
u_flags:x:1002:1002:Scripted User:/home/u_flags:/bin/bash
$ ls -la /home/u_flags
-rw-r--r-- 1 u_flags u_flags  220 .bash_logout
-rw-r--r-- 1 u_flags u_flags 3771 .bashrc
-rw-r--r-- 1 u_flags u_flags  807 .profile
```

`-m` created the home and copied `/etc/skel` into it. Still no password — which is correct for a
service account you never want anyone to log into.

**3. `adduser tester` — the recommended way on Ubuntu:**

```
info: Adding user `tester' ...
info: Selecting UID/GID from range 1000 to 59999 ...
info: Adding new group `tester' (1003) ...
info: Adding new user `tester' (1003) with group `tester (1003)' ...
info: Creating home directory `/home/tester' ...
info: Copying files from `/etc/skel' ...
New password: Retype new password: passwd: password updated successfully
Changing the user information for tester
	Full Name []: ...
info: Adding new user `tester' to supplemental / extra groups `users' ...
```

Every step the other two made me think about, done in the right order, with a usable account at the end.

### Checking it worked

```
$ id tester
uid=1003(tester) gid=1003(tester) groups=1003(tester),100(users)
$ getent passwd tester
tester:x:1003:1003:Anantha Test User,,,:/home/tester:/bin/bash
```

`id` gives UID, primary GID and every supplementary group — fastest "who is this account really".
`getent passwd` goes through NSS, so unlike `grep /etc/passwd` it also finds LDAP/SSSD users. The
`Anantha Test User,,,` is the GECOS field: name, room, work phone, home phone, comma-separated.

The shadow file is where the real difference shows (hashes truncated here):

```
u_bare:!
u_flags:!
tester:$y$j9T$opnEHze1dZtp...
```

`!` means locked, no usable password. Only the `adduser` account has an actual hash — `$y$` is
yescrypt, the Ubuntu 24.04 default — because `adduser` ran `passwd` for me and the other two didn't.

`chage -l tester` showed the aging policy: never expires, minimum 0 days between changes, 7 days of
warning.

### The `-aG` trap

```
$ usermod -aG sudo tester
$ groups tester
tester : tester sudo users

$ usermod -G users tester      # deliberately WITHOUT -a
$ groups tester
tester : tester users
```

`sudo` is gone. `-G` *sets* the supplementary group list; `-a` appends to it. Forget the `-a` on your
own admin account over SSH and you've locked yourself out of root on that machine.

### Files these commands touch

| File | What's in it |
|---|---|
| `/etc/passwd` | one line per account: name, `x`, UID, GID, GECOS, home, shell. World-readable |
| `/etc/shadow` | password hashes and aging. Mode 0640 root:shadow — which is why `x` sits in passwd |
| `/etc/group` | group name, GID, and the supplementary member list |
| `/etc/gshadow` | group passwords and admins. Almost nobody uses these |
| `/etc/skel/` | template copied into every new home (`.bashrc`, `.profile`, `.bash_logout`) |
| `/etc/login.defs` | UID/GID ranges, password aging defaults, umask |
| `/etc/default/useradd` | `useradd`'s defaults — where that `/bin/sh` came from |
| `/etc/adduser.conf` | `adduser`'s own policy: UID range, home permissions, extra groups |

Edit these by hand with `vipw` / `vigr`, not `vi` — they take the lock, so you can't corrupt the file
against a concurrent `useradd`.

### Cleanup

```
$ deluser --remove-home tester
info: Looking for files to backup/remove ...
info: Removing files ...
info: Removing user `tester' ...
$ getent passwd u_bare u_flags tester
(exit 2 — none of the three resolve any more)
```

`deluser --remove-home` needs the `perl` package; my first attempt died with
`fatal: In order to use the --remove-home ... you need to install the perl package`, which is why perl
is in the Dockerfile. `userdel -r` is the portable equivalent.

**Takeaway:** `adduser` for a human at a terminal on Debian/Ubuntu. `useradd` with explicit flags for
scripts, Dockerfiles, and anything that also has to work on RHEL.

---

## Task 3 — journalctl

The **systemd journal** is a structured, indexed, binary log. `journald` collects stdout/stderr from
every unit, plus syslog, kernel and audit messages, into one store, and tags each record with fields it
captured itself rather than parsed out of a string: `_SYSTEMD_UNIT`, `_PID`, `_UID`, `_COMM`, `_BOOT_ID`,
`PRIORITY`, and both monotonic and wall-clock timestamps.

That's why you need `journalctl` instead of `cat` — the on-disk format is binary, so `cat` gives noise.
And it's why you *want* it: those fields are the queryable part. Grepping text logs for "only errors,
from nginx, on the previous boot" means writing a regex against whatever format that daemon happened to
print. Here it's three field lookups.

Ran on systemd 255 (255.4-1ubuntu8.17), Ubuntu 24.04.4, in the container described above.

### Persistent or not

```
$ journalctl --disk-usage
Archived and active journals take up 8.0M in the file system.
-> /var/log/journal exists: logs SURVIVE reboots.
```

This matters more than it sounds:

- `/var/log/journal/` exists → persistent, logs survive reboots.
- Only `/run/log/journal/` → tmpfs, **wiped on every boot**. Default on a lot of minimal images, and
  the reason for "I rebooted to fix it and now the logs are gone".
- Fix: `sudo mkdir -p /var/log/journal && sudo systemctl restart systemd-journald`. My systemd
  Dockerfile does exactly that, which is why the run above is persistent.

### Reading it

| Command | What it does |
|---|---|
| `journalctl -n 15` | last 15 entries |
| `journalctl -r` | newest first |
| `journalctl -f` | follow live, like `tail -f` |
| `journalctl --no-pager` | don't launch `less` — what you want in a script |
| `journalctl -u nginx` | just that unit |
| `journalctl -xeu nginx` | the reflex after a failed `systemctl start`: `-e` jump to end, `-x` add explanations, `-u` that unit |
| `journalctl -k` | kernel ring buffer, the `dmesg` equivalent |
| `journalctl -o json-pretty -n 1` | one record with every structured field visible |

### Boots

```
$ journalctl --list-boots
IDX BOOT ID                          FIRST ENTRY                 LAST ENTRY
  0 38b240d1c81c4e7a87887dbf1f71b94e Fri 2026-09-04 18:01:18 UTC Fri 2026-09-04 18:03:12 UTC
```

One boot, because the container had just started. On a real box you get one row per boot, and
`journalctl -b -1` reads the *previous* one — which is where you find out why it crashed, since the
machine obviously couldn't write the reason anywhere useful at the time.

### Logs for one service

The script picks a unit that exists; here it chose `systemd-logind`.

```
$ systemctl status systemd-logind --no-pager
● systemd-logind.service - User Login Management
     Loaded: loaded (/usr/lib/systemd/system/systemd-logind.service; static)
     Active: active (running) since Fri 2026-09-04 18:01:18 UTC; 1min 59s ago
   Main PID: 80 (systemd-logind)
     Status: "Processing requests..."
      Tasks: 1 (limit: 9113)
```

`systemctl status` shows the last few journal lines inline; `journalctl -u <unit>` gives you all of
them, and `-u <unit> -f` follows just that unit while you poke it.

### Priority

Priorities are the syslog numbers: 0 emerg, 1 alert, 2 crit, 3 err, 4 warning, 5 notice, 6 info,
7 debug. **`-p err` is inclusive of everything worse** — you get 0–3, not just 3. That reads backwards
from the numbers and it's the thing I had to look up twice.

```
$ journalctl -p err -b --no-pager
Sep 04 18:01:18 kernel: PCI: Fatal: No config space access function found
Sep 04 18:01:18 unknown: WSL (1 - init(docker-desktop)) ERROR: ConfigApplyWindowsLibPath:2091: ...
Sep 04 18:01:18 kernel: misc dxg: dxgk: dxgkio_query_adapter_info: Ioctl failed: -22
```

Worth understanding *why* those are there: a container doesn't get its own kernel. `journalctl -k` and
these kernel-priority records come from the shared WSL2 kernel underneath Docker Desktop, so I'm reading
the host's kernel log — GPU passthrough (`dxg`) and WSL init errors that have nothing to do with my
container. Namespaces isolate processes, mounts and networking; they don't isolate the kernel ring
buffer.

`journalctl -p warning..err` takes a range instead.

### Time

```bash
journalctl --since "1 hour ago"
journalctl --since today --until "12:00"
journalctl --since today -p err
```

`--since` understands `today`, `yesterday`, `-1h`, and absolute timestamps.

### The other filters

Any field can be matched directly as `FIELD=value`:

```
$ journalctl _PID=1 -n 5 --no-pager
Sep 04 18:01:18 systemd[1]: Starting systemd-update-utmp-runlevel.service ...
Sep 04 18:01:18 systemd[1]: Startup finished in 462ms.
```

And `-o json-pretty` shows what's actually stored per record:

```json
{
	"_TRANSPORT" : "kernel",
	"MESSAGE" : "docker0: port 17(veth4835feb) entered forwarding state",
	"PRIORITY" : "6",
	"_BOOT_ID" : "38b240d1c81c4e7a87887dbf1f71b94e",
	"_HOSTNAME" : "52d8de9e7181",
	"__REALTIME_TIMESTAMP" : "1788544992222751",
	"_MACHINE_ID" : "8b121157d3904b4a8a297b45839c6d93"
}
```

Every one of those keys is filterable. That's the actual argument for the journal over text files.

**A gotcha I hit:** `journalctl -g 'Failed|error'` returned `-- No entries --`, on a journal that
visibly contains both `ERROR` and `Ioctl failed`. `-g` is **smart-case**: an all-lowercase pattern
matches case-insensitively, but the moment you type a capital letter (`Failed`) the whole pattern goes
case-sensitive. So `Failed` missed `failed`, and `error` — which would have matched on its own — was
dragged into case-sensitive mode by its neighbour and missed `ERROR`. `journalctl -g 'failed|error'`
finds both.

### Housekeeping

```bash
sudo journalctl --vacuum-size=200M   # trim down to 200 MB
sudo journalctl --vacuum-time=7d     # drop anything older than a week
sudo journalctl --verify             # integrity check
```

Permanent limits go in `/etc/systemd/journald.conf` (`SystemMaxUse=`, `MaxRetentionSec=`). A normal
user only sees their own messages; the full system journal needs root or membership in the
`systemd-journal` group.

---

## Task 4 — command cheat sheet

Grouped by what I'm actually trying to do, not alphabetically.

**Where am I, what's here**

```bash
pwd                     ls -la          ls -lh          ls -lt      # newest first
ls -li                  # inode + link count — task 1 lives in this flag
tree -L 2               du -sh *        du -h --max-depth=1 | sort -h
df -h                   # which filesystem, how full
stat file               # inode, links, size, all three timestamps
file thing              # what IS this — how I checked adduser was Perl
```

**Finding things**

```bash
find . -name '*.log'            find . -type f -mmin -30      # changed in last 30 min
find . -samefile x              find . -xtype l               # hard links / broken symlinks
find . -type f -size +100M
grep -rn "pattern" .            grep -ri        grep -v        grep -c
command -v cmd                  # the portable "where is it"; which/type also work
```

**Reading files**

```bash
less file       # / search, G end, q quit
head -20        tail -20        tail -f
cat -A          # show tabs and line endings — CRLF hunting
wc -l           sort            sort -u        uniq -c        cut -d: -f1
sed -n '10,20p' file            awk '{print $1}'
```

**Processes**

```bash
ps aux | grep thing      pgrep -a name      top      htop
kill PID       kill -9 PID      pkill -f pattern
lsof -i :8080            # who has that port
jobs      fg      bg      Ctrl-Z      nohup cmd &
```

**Permissions and users**

```bash
id            whoami          groups user       getent passwd user
sudo -i       su - user
chmod 644 f   chmod +x f      chmod -R g+w d
chown user:group f            umask
adduser bob                   # Debian/Ubuntu, interactive
useradd -m -s /bin/bash bob   # scripts, portable
usermod -aG sudo bob          # THE -a IS NOT OPTIONAL
deluser --remove-home bob     # userdel -r elsewhere
```

**Links**

```bash
ln target name           # hard
ln -s target name        # soft
readlink -f name         # resolve the whole chain
```

**Services and logs**

```bash
systemctl status|start|stop|restart|enable|disable unit
systemctl list-units --type=service
systemctl daemon-reload           # after editing a unit file
journalctl -xeu unit              journalctl -u unit -f
journalctl -b -1 -p err           # errors from the boot that died
```

**Network**

```bash
ip a       ip r       ss -tulpn      # ss replaced netstat
ping -c 4 host         curl -I url       curl -sS url
dig +short host        traceroute host
```

**Archives and transfer**

```bash
tar -czf out.tar.gz dir/       tar -xzf in.tar.gz       tar -tzf in.tar.gz   # list before extracting
scp file host:/path            rsync -avh --progress src/ dst/
```

**Getting unstuck**

```bash
man cmd        cmd --help        apropos keyword
history | grep thing             Ctrl-R
!!             sudo !!
set -euo pipefail                # top of every script I write
```

---

## What actually got tested

| Task | Ran for real? | Where |
|---|---|---|
| 1 — links | **yes**, complete | `ubuntu:24.04` container → `output/01-links-practice-output.txt` |
| 2 — adduser/useradd | **yes**, complete including cleanup | same + `adduser file sudo passwd perl` → `output/02-user-practice-output.txt` |
| 3 — journalctl | **yes**, complete | `--privileged` container, systemd 255 as PID 1 → `output/03-journalctl-practice-output.txt` |
| 4 — cheat sheet | n/a, it's a write-up | commands I use |

Two caveats on task 3, since "it ran" isn't the same as "it's representative":

- **The kernel log isn't the container's.** `journalctl -k` and the kernel-priority errors come from
  the shared WSL2 kernel under Docker Desktop, not from anything my container did. On a real machine
  those lines would be about that machine's hardware.
- **One boot only.** `--list-boots` had a single entry, so `journalctl -b -1` had nothing to show. On a
  real box that's the single most useful command here, and I couldn't demonstrate it.

Everything else — persistence, unit filtering, priority ranges, time filtering, field matching,
`json-pretty` — is genuine output from a real journald.

## Notes

- The `ubuntu:24.04` image is more minimal than I assumed. No `adduser`, no `file`, no `perl`. The first
  run died on `adduser: command not found`, and the first cleanup died on `deluser` needing perl.
  Baking a small image beat re-installing packages on every run.
- `02-user-practice.sh` can't be fully driven by piping answers into it: `adduser` reads stdin until EOF
  and swallows the rest, so steps 5 and 6 never see their answers and silently skip. The output file has
  those two re-run by hand underneath, clearly labelled. Interactively it's a non-issue — but it's a good
  reminder that "prompt with `read`" and "pipe answers in" don't compose when something in the middle
  also reads stdin.
- Getting systemd up in a container was easier than expected: `--privileged --cgroupns=host` plus the
  cgroup mount, and it booted in 462 ms. That turned task 3 from a paper exercise into a real one.
- `-p err` including everything *more* severe is the flag I keep getting backwards.
- `-g` being smart-case cost me a few minutes of believing the journal was empty.
- The symlink-heals-itself step is what finally made soft links click. A symlink doesn't reference a
  file, it references a *name*, and that name can be re-pointed at something completely different
  behind its back.

---
