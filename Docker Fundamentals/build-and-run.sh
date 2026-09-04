#!/usr/bin/env bash
#
# build-and-run.sh -- build, start and check the six Hello World containers.
#
#   bash build-and-run.sh            build + up + check   (same as: all)
#   bash build-and-run.sh build      build the images only
#   bash build-and-run.sh up         start containers from images already built
#   bash build-and-run.sh check      verify what is currently running
#   bash build-and-run.sh down       stop and remove the containers
#   bash build-and-run.sh purge      down, then delete the images too
#
#   bash build-and-run.sh check java     any subcommand takes a filter, so
#   bash build-and-run.sh all react      only matching apps are touched
#
# The app list is data, not code: see apps.manifest next to this script.

set -uo pipefail

cd "$(dirname "$0")" || exit 1

# Docker Desktop puts docker.exe here; Git Bash does not pick it up on its own.
export PATH="$PATH:/c/Program Files/Docker/Docker/resources/bin"

MANIFEST="apps.manifest"
FILTER="${2:-}"
PASSED=0
FAILED=0

banner() { printf '\n== %s\n' "$1"; }

# Reads the manifest and calls "$1 folder image hostport cport marker" once per
# app, skipping comments, blank lines and anything the filter excludes.
each_app() {
    local fn=$1 folder image hp cp marker
    while IFS='|' read -r folder image hp cp marker; do
        case "$folder" in \#*|'') continue ;; esac
        folder=$(echo "$folder" | xargs)
        image=$(echo "$image" | xargs)
        hp=$(echo "$hp" | xargs)
        cp=$(echo "$cp" | xargs)
        marker=$(echo "$marker" | sed -e 's/^ *//' -e 's/ *$//')
        [ -z "$folder" ] && continue
        if [ -n "$FILTER" ] && [[ "$folder$image" != *"$FILTER"* ]]; then continue; fi
        "$fn" "$folder" "$image" "$hp" "$cp" "$marker"
    done < "$MANIFEST"
}

require_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "docker is not on PATH."
        echo 'Try: export PATH="$PATH:/c/Program Files/Docker/Docker/resources/bin"'
        exit 1
    fi
    if ! docker info >/dev/null 2>&1; then
        echo "docker is installed but the daemon is not answering."
        echo "Start Docker Desktop, wait for 'Engine running', then re-run this."
        exit 1
    fi
    docker version --format '   client {{.Client.Version}} / server {{.Server.Version}} ({{.Server.Os}})'
}

do_build() {
    local folder=$1 image=$2
    printf '   %-11s <- %s/\n' "$image" "$folder"
    if docker build -q -t "$image" "$folder" >/dev/null 2>&1; then
        echo "               built"
    else
        echo "               BUILD FAILED -- last lines of the real build:"
        docker build -t "$image" "$folder" 2>&1 | tail -20 | sed 's/^/               /'
    fi
}

do_up() {
    local image=$2 hp=$3 cp=$4
    # A leftover container from a previous run would make docker run fail with
    # "name already in use", so clear it first.
    docker rm -f "$image" >/dev/null 2>&1
    if docker run -d --name "$image" -p "${hp}:${cp}" "$image" >/dev/null 2>&1; then
        printf '   %-11s http://localhost:%-5s (container port %s)\n' "$image" "$hp" "$cp"
    else
        printf '   %-11s DID NOT START\n' "$image"
        docker run --rm -p "${hp}:${cp}" "$image" 2>&1 | head -5 | sed 's/^/               /'
    fi
}

do_down() {
    local image=$2
    if docker rm -f "$image" >/dev/null 2>&1; then
        printf '   removed  %s\n' "$image"
    else
        printf '   not up   %s\n' "$image"
    fi
}

do_purge() {
    local image=$2
    docker rmi -f "$image" >/dev/null 2>&1 && printf '   deleted image %s\n' "$image"
}

# The check decides whether the homework actually works, so it asks three
# separate questions and only prints PASS when all three agree.
do_check() {
    local image=$2 hp=$3 marker=$5
    local state code body

    # 1. Is the container running? Ask docker, not the network. A dead
    #    container plus something else listening on that port must never read
    #    as a pass.
    state=$(docker inspect -f '{{.State.Status}}' "$image" 2>/dev/null)
    if [ "$state" != "running" ]; then
        printf '   FAIL  %-11s container state: %s\n' "$image" "${state:-no such container}"
        docker logs --tail 4 "$image" 2>&1 | sed 's/^/            /'
        FAILED=$((FAILED + 1))
        return
    fi

    # 2. Does it answer 200?
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "http://localhost:$hp/")
    # 3. Is the body THIS app rather than a neighbour that grabbed the port?
    body=$(curl -s --max-time 8 "http://localhost:$hp/")

    if [ "$code" = "200" ] && printf '%s' "$body" | grep -qF -- "$marker"; then
        printf '   PASS  %-11s HTTP %s  http://localhost:%s\n' "$image" "$code" "$hp"
        PASSED=$((PASSED + 1))
    else
        printf '   FAIL  %-11s HTTP %s  did not contain: %s\n' "$image" "$code" "$marker"
        docker logs --tail 4 "$image" 2>&1 | sed 's/^/            /'
        FAILED=$((FAILED + 1))
    fi
}

# Containers are not ready the instant docker run returns. Polling beats a
# fixed sleep: the static servers answer at once, the JVM needs a second or two.
wait_ready() {
    local hp=$3 i
    for i in $(seq 1 40); do
        curl -sf -o /dev/null --max-time 1 "http://localhost:$hp/" && return 0
    done
    return 1
}

cmd_build() {
    banner "building images"
    each_app do_build
    banner "images"
    docker images --filter 'reference=ana-*' \
        --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}'
}

cmd_up() {
    banner "starting containers"
    each_app do_up
    banner "docker ps"
    docker ps --filter 'name=ana-' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
}

cmd_check() {
    banner "waiting for the slower containers"
    each_app wait_ready
    banner "checking each app"
    each_app do_check
    banner "result: $PASSED passed, $FAILED failed"
    [ "$FAILED" -eq 0 ]
}

cmd_down()  { banner "removing containers"; each_app do_down; }
cmd_purge() { cmd_down; banner "removing images"; each_app do_purge; }

case "${1:-all}" in
    build) require_docker; cmd_build ;;
    up)    require_docker; cmd_up ;;
    check) require_docker; cmd_check ;;
    down)  require_docker; cmd_down ;;
    purge) require_docker; cmd_purge ;;
    all)
        require_docker
        cmd_build
        cmd_up
        cmd_check
        rc=$?
        banner "open these in a browser"
        awk -F'|' '!/^#/ && NF>2 {gsub(/ /,"",$2); gsub(/ /,"",$3);
                   printf "   http://localhost:%-6s %s\n", $3, $2}' "$MANIFEST"
        printf '\n   tear down with: bash build-and-run.sh down\n'
        exit $rc
        ;;
    *)
        echo "unknown subcommand: $1"
        sed -n '3,17p' "$0" | cut -c3-
        exit 2
        ;;
esac
