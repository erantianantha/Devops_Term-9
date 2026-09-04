#!/usr/bin/env bash
#
# task3-bindmount.sh — mount a host directory into a container, then edit the
# file on the host and watch the container serve the new version without being
# restarted, rebuilt or touched in any way.
#
#   bash task3-bindmount.sh
#   bash task3-bindmount.sh clean
#
# The edit is done by this script and then undone, so the file in the repo is
# always version 1 and the demo can be run again.

set -u
export PATH="$PATH:/c/Program Files/Docker/Docker/resources/bin"
cd "$(dirname "$0")" || exit 1

NAME=ana-bindmount
PORT=8182
SRC="$(pwd)/task3-bindmount"

say() { printf '\n--- %s\n' "$*"; }

if [ "${1:-}" = "clean" ]; then
    docker rm -f "$NAME" >/dev/null 2>&1 && echo "removed $NAME"
    exit 0
fi

docker info >/dev/null 2>&1 || { echo "docker daemon is not running"; exit 1; }

say "starting nginx with the host directory mounted read-only"
docker rm -f "$NAME" >/dev/null 2>&1
# MSYS_NO_PATHCONV=1 is required in Git Bash. Without it, Git Bash sees
# /usr/share/nginx/html, decides it is a unix path that needs translating, and
# rewrites it to C:/Program Files/Git/usr/share/nginx/html before docker ever
# sees the argument -- so the mount lands somewhere meaningless.
MSYS_NO_PATHCONV=1 docker run -d --name "$NAME" -p "$PORT:80" \
    -v "$SRC:/usr/share/nginx/html:ro" nginx:alpine >/dev/null
echo "  \$ docker run -d -p $PORT:80 -v \"\$PWD/task3-bindmount:/usr/share/nginx/html:ro\" nginx:alpine"
sleep 2

say "what docker says the mount is"
docker inspect "$NAME" --format \
  '{{range .Mounts}}  type={{.Type}}  ro={{not .RW}}{{"\n"}}  source={{.Source}}{{"\n"}}  target={{.Destination}}{{end}}'
echo "  type is 'bind' -- it points at a directory I chose. A named volume"
echo "  would say type=volume and be stored under docker's own data root."

say "version 1, as served"
curl -s -m 5 "http://localhost:$PORT/" | grep -E '<title>|VERSION|<h1>' | sed 's/^ */  /'

say "editing the file ON THE HOST -- the container is not touched"
cp task3-bindmount/index.html /tmp/bindmount-v1.html
sed -i -e 's/VERSION 1/VERSION 2/' \
       -e 's/bind mount &mdash; version 1/bind mount \&mdash; version 2/' \
       -e 's/bind mount — version 1/bind mount — version 2/' \
       -e 's|<h1>Served from a bind mount</h1>|<h1>Edited while it was running</h1>|' \
       -e 's|#5d8c46|#c2410c|' \
       task3-bindmount/index.html
echo "  sed changed the file on the Windows filesystem. No docker command ran."

say "version 2, as served -- same container, no restart"
curl -s -m 5 "http://localhost:$PORT/" | grep -E '<title>|VERSION|<h1>' | sed 's/^ */  /'
docker ps --filter "name=$NAME" --format 'table {{.Names}}\t{{.Status}}'
echo "  the STATUS uptime never reset: this container has not been restarted."

say "read-only really is read-only"
# :ro is not a suggestion. The kernel mounts it read-only, so even root in the
# container cannot write to it -- which is what makes a bind mount safe to use
# for config that the container has no business editing.
docker exec "$NAME" sh -c 'echo tampered >> /usr/share/nginx/html/index.html' 2>&1 \
    | head -2 | sed 's/^/  /'

say "the mount REPLACED the directory, it did not merge with it"
# MSYS_NO_PATHCONV=1 again. Any argument that looks like a unix path gets
# rewritten by Git Bash before docker sees it, which is why the first run of
# this script reported
#   ls: C:/Program Files/Git/usr/share/nginx/html: No such file or directory
# for a path that was never typed.
MSYS_NO_PATHCONV=1 docker exec "$NAME" ls -la /usr/share/nginx/html | sed 's/^/  /'
echo "  nginx's own index.html and 50x.html are gone. They are still in the"
echo "  image and come back the moment the mount is removed:"
MSYS_NO_PATHCONV=1 docker run --rm nginx:alpine ls /usr/share/nginx/html | sed 's/^/    /'

say "putting the file back to version 1"
cp /tmp/bindmount-v1.html task3-bindmount/index.html
curl -s -m 5 "http://localhost:$PORT/" | grep -E 'VERSION' | sed 's/^ */  /'

cat <<'TXT'

  bind mount vs named volume vs tmpfs

    bind mount    -v /abs/host/path:/in/container   a directory you point at
                  edit on the host, container sees it immediately.
                  for development and for config files.

    named volume  -v myvol:/in/container            docker manages the storage
                  survives the container, lives under docker's data root.
                  for databases and anything that must persist.

    tmpfs         --tmpfs /in/container             memory only, gone on stop
                  for secrets and scratch files that must never hit a disk.

  How docker tells the first two apart: if the part before the colon starts
  with / or a drive letter it is a bind mount, otherwise it is treated as a
  volume NAME and docker creates it. Typing `-v data:/var/lib/postgresql/data`
  when you meant `./data` silently gives you a volume instead of a directory,
  and everything appears to work until you go looking for the files.

  Also worth knowing: a bind mount whose source does not exist does not error.
  Docker creates an empty directory and mounts that, so a typo in the path
  shows up as a mysteriously empty document root.

  clean up: bash task3-bindmount.sh clean
TXT
