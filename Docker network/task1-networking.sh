#!/usr/bin/env bash
#
# task1-networking.sh — user-defined bridge networks, and what they do and do
# not let containers reach.
#
#   bash task1-networking.sh          build the topology and test it
#   bash task1-networking.sh clean    remove the containers and networks
#
# Topology:
#
#     gateway ──[ edge-net ]── service ──[ core-net ]── store
#      nginx                    nginx      (on BOTH)    postgres
#     :8180
#
#     castaway ──[ island-net ]        third network, one container, no friends
#
# service is on two networks on purpose: it is the tier that is allowed to talk
# to both sides, which is the normal shape of a web/api/database split.

set -u
export PATH="$PATH:/c/Program Files/Docker/Docker/resources/bin"

NETS=(edge-net core-net island-net)
CONTAINERS=(gateway service store castaway)
PGPASS=task1secret

say() { printf '\n--- %s\n' "$*"; }

if [ "${1:-}" = "clean" ]; then
    say "removing containers"
    for c in "${CONTAINERS[@]}"; do docker rm -f "$c" >/dev/null 2>&1 && echo "  $c"; done
    say "removing networks"
    for n in "${NETS[@]}"; do docker network rm "$n" >/dev/null 2>&1 && echo "  $n"; done
    exit 0
fi

docker info >/dev/null 2>&1 || { echo "docker daemon is not running"; exit 1; }

# ---------------------------------------------------------------------------
say "creating three user-defined bridge networks"
for n in "${NETS[@]}"; do
    docker network rm "$n" >/dev/null 2>&1
    docker network create "$n" >/dev/null && echo "  created $n"
done
docker network ls --filter driver=bridge --format 'table {{.Name}}\t{{.Driver}}\t{{.Scope}}'

# ---------------------------------------------------------------------------
say "starting containers"
for c in "${CONTAINERS[@]}"; do docker rm -f "$c" >/dev/null 2>&1; done

docker run -d --name gateway  --network edge-net -p 8180:80 nginx:alpine >/dev/null
docker run -d --name service  --network edge-net nginx:alpine >/dev/null
docker run -d --name store    --network core-net \
    -e POSTGRES_PASSWORD="$PGPASS" -e POSTGRES_DB=appdb postgres:16-alpine >/dev/null
docker run -d --name castaway --network island-net nginx:alpine >/dev/null

# `docker run` accepts only one --network, so the second membership is added
# afterwards. This is the whole trick behind a multi-tier setup.
docker network connect core-net service
echo "  service is now attached to edge-net AND core-net"

docker ps --filter name=gateway --filter name=service --filter name=store \
          --filter name=castaway --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'

say "addresses handed out by each network"
for c in "${CONTAINERS[@]}"; do
    printf '  %-9s %s\n' "$c" \
      "$(docker inspect -f '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}={{$conf.IPAddress}} {{end}}' "$c")"
done

# ---------------------------------------------------------------------------
say "waiting for postgres to accept TCP connections"
# pg_isready is the readiness check that matches how clients actually connect.
# Checking "is the process running" is not the same thing: postgres opens its
# socket several seconds before it will answer a query.
for i in $(seq 1 40); do
    if docker exec store pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1; then
        echo "  ready after ${i}s"
        break
    fi
    sleep 1
done

# ---------------------------------------------------------------------------
# Each probe runs INSIDE a container and addresses the target BY NAME, which is
# the point: on a user-defined network Docker runs a DNS resolver that answers
# for container names, so nothing here hardcodes an IP.
probe_http() {   # probe_http <from> <to> <expect ok|fail>
    local from=$1 to=$2 expect=$3 out
    if out=$(docker exec "$from" timeout 5 wget -q -O /dev/null "http://$to/" 2>&1); then
        printf '  %-9s -> %-9s :80    OK\n' "$from" "$to"
        [ "$expect" = ok ] || printf '        UNEXPECTED: this was meant to fail\n'
    else
        printf '  %-9s -> %-9s :80    unreachable\n' "$from" "$to"
        [ "$expect" = fail ] || printf '        UNEXPECTED: this was meant to work\n'
    fi
}

probe_pg() {     # probe_pg <from> <to> <expect>
    local from=$1 to=$2 expect=$3
    if docker exec "$from" timeout 5 sh -c "nc -z $to 5432" 2>/dev/null; then
        printf '  %-9s -> %-9s :5432  OK\n' "$from" "$to"
        [ "$expect" = ok ] || printf '        UNEXPECTED: this was meant to fail\n'
    else
        printf '  %-9s -> %-9s :5432  unreachable\n' "$from" "$to"
        [ "$expect" = fail ] || printf '        UNEXPECTED: this was meant to work\n'
    fi
}

say "connections that SHOULD work (a shared network)"
probe_http gateway service ok
probe_http service gateway ok
probe_pg   service store   ok

say "connections that SHOULD fail (no shared network)"
probe_http gateway castaway fail
probe_http castaway service fail
probe_pg   gateway store    fail

say "what the failure actually is"
echo "  \$ docker exec gateway nslookup store"
docker exec gateway timeout 5 nslookup store 2>&1 | tail -4 | sed 's/^/    /'
echo
echo "  the name does not resolve. gateway is not blocked from reaching store,"
echo "  it cannot even work out an address for it: docker's embedded DNS only"
echo "  answers for containers that share a network with the asker."

say "name resolution working, for contrast"
echo "  \$ docker exec gateway nslookup service"
docker exec gateway timeout 5 nslookup service 2>&1 | tail -4 | sed 's/^/    /'

say "fetching a page across the network by name"
docker exec gateway timeout 5 wget -q -O - http://service/ 2>/dev/null | head -5 | sed 's/^/    /'

say "the database answering on the network it shares with service"
docker exec store psql -U postgres -d appdb -c 'SELECT version();' 2>&1 | head -3 | sed 's/^/    /'
docker exec store psql -U postgres -c '\l' 2>&1 | head -6 | sed 's/^/    /'

say "done"
echo "  gateway is published: http://localhost:8180"
echo "  store has no published port at all, on purpose"
echo "  clean up with: bash task1-networking.sh clean"
