#!/usr/bin/env bash
#
# task2-host-network.sh — --network host, and what it means on Docker Desktop.
#
#   bash task2-host-network.sh
#   bash task2-host-network.sh clean
#
# Apache is told to listen on 8183 rather than 80, because in host mode there
# is no port mapping to move it out of the way of anything already using 80.
# That is itself the first lesson: with --network host you are binding real
# ports on the Docker host and you have to think about what else is there.

set -u
export PATH="$PATH:/c/Program Files/Docker/Docker/resources/bin"

HOSTC=ana-apache-hostnet
PUBC=ana-apache-published
PORT=8183

say() { printf '\n--- %s\n' "$*"; }

if [ "${1:-}" = "clean" ]; then
    for c in "$HOSTC" "$PUBC"; do docker rm -f "$c" >/dev/null 2>&1 && echo "removed $c"; done
    exit 0
fi

docker info >/dev/null 2>&1 || { echo "docker daemon is not running"; exit 1; }

say "the image"
# There is no official image called "apache2" -- that is the Debian package
# name. The Apache HTTP Server image is `httpd`.
docker pull -q httpd:2.4-alpine >/dev/null && echo "  httpd:2.4-alpine pulled"

say "running it with --network host"
docker rm -f "$HOSTC" >/dev/null 2>&1
docker run -d --name "$HOSTC" --network host httpd:2.4-alpine \
    sh -c "sed -i 's/^Listen 80\$/Listen $PORT/' conf/httpd.conf && httpd-foreground" >/dev/null
sleep 3
echo "  \$ docker run -d --network host httpd:2.4-alpine   (Listen $PORT)"

say "docker ps"
docker ps --filter "name=$HOSTC" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo "  the PORTS column is EMPTY, and that is correct: there is no mapping,"
echo "  because there is no separate network namespace to map out of."

say "no -p was given, and none is allowed"
docker rm -f probe >/dev/null 2>&1
docker run --rm --name probe --network host -p 9999:80 alpine:3.20 true 2>&1 | head -3 | sed 's/^/  /'

say "reaching it from inside the docker host"
docker run --rm --network host alpine:3.20 \
    sh -c "wget -q -O - http://localhost:$PORT/ 2>&1 | head -6" | sed 's/^/  /'

say "what the docker host thinks is listening"
docker run --rm --network host alpine:3.20 \
    sh -c "netstat -tln 2>/dev/null | grep ':$PORT '" | sed 's/^/  /'

say "reaching it from Windows"
code=$(curl -s -o /dev/null -m 5 -w '%{http_code}' "http://localhost:$PORT/" 2>/dev/null)
echo "  curl http://localhost:$PORT/  ->  HTTP ${code:-no response}"

cat <<'TXT'

  If that says "no response", nothing is broken. Docker Desktop does not run
  Linux containers on Windows directly -- it runs them inside a WSL2 virtual
  machine, and THAT vm is "the docker host". --network host attached Apache to
  the vm's network stack, so it really is on the docker host's port, just not
  on Windows'.

  On a Linux machine there is no vm in between and http://localhost would
  answer immediately. This is the practical reason --network host is a Linux
  feature and -p is the portable way to publish anything.
TXT

say "the same image published the normal way, so Windows can reach it"
docker rm -f "$PUBC" >/dev/null 2>&1
docker run -d --name "$PUBC" -p 8181:80 httpd:2.4-alpine >/dev/null
sleep 2
docker ps --filter "name=$PUBC" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo
echo "  \$ curl -I http://localhost:8181/"
curl -sI -m 5 http://localhost:8181/ | head -4 | sed 's/^/    /'

cat <<'TXT'

  Now the PORTS column has 0.0.0.0:8181->80/tcp and Windows can reach it. The
  container is back in its own namespace and docker is forwarding for it.

  When host networking is worth it:
    - throughput: it skips docker's NAT hop, which matters for high packet
      rates, not for a web page
    - services that open many ports, where publishing each one is tedious
    - protocols NAT breaks: DHCP, mDNS, anything broadcast, or anything that
      needs to see the real client IP
    - monitoring agents that must see the host's real interfaces

  What it costs:
    - no network isolation at all: the container can bind any host port and
      see traffic it has no business seeing
    - port collisions with the host and with every other host-mode container
    - it is Linux-only in practice, as demonstrated above

  clean up: bash task2-host-network.sh clean
TXT
