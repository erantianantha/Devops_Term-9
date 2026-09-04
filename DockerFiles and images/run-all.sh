#!/usr/bin/env bash
#
# run-all.sh -- everything this folder claims, executed and measured.
#
#   bash run-all.sh            task 1, task 2 and task 3 in order
#   bash run-all.sh sizes      task 1 only: build both Dockerfiles, compare
#   bash run-all.sh cache      task 2 only: the caching experiments
#   bash run-all.sh deploy     task 3 only: build and run the three apps
#   bash run-all.sh clean      remove the containers this script starts
#
# Ports: 8090 for the task 1 app, 8091/8092/8093 for the three deployments.

set -u
cd "$(dirname "$0")" || exit 1
export PATH="$PATH:/c/Program Files/Docker/Docker/resources/bin"

# name ; folder ; host port ; container port
DEPLOYMENTS=(
  "ana-deploy-node;task3-deployments/nodejs-app;8091;3000"
  "ana-deploy-python;task3-deployments/python-app;8092;5000"
  "ana-deploy-java;task3-deployments/java-app;8093;8080"
)

section() { printf '\n########## %s\n\n' "$1"; }
size() { docker images --format '{{.Size}}' "$1" | head -1; }

# ---------------------------------------------------------------- task 1 ----
task_sizes() {
    section "TASK 1  multi-stage vs single-stage, same application"

    echo "\$ docker build -t ana-ms-multi  multi-stage-app"
    docker build -q -t ana-ms-multi multi-stage-app >/dev/null || return 1
    echo "\$ docker build -t ana-ms-single -f multi-stage-app/Dockerfile.single multi-stage-app"
    docker build -q -t ana-ms-single -f multi-stage-app/Dockerfile.single multi-stage-app >/dev/null || return 1

    echo
    docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' \
        | grep -E 'REPOSITORY|ana-ms-'
    echo
    echo "what is in the difference (contents of the single-stage image that"
    echo "the multi-stage one does not carry):"
    docker run --rm ana-ms-single sh -c \
      'echo "  node_modules : $(du -sh node_modules 2>/dev/null | cut -f1)";
       echo "  esbuild bin  : $(du -sh node_modules/@esbuild 2>/dev/null | cut -f1)";
       echo "  source tree  : $(du -sh src build.js 2>/dev/null | tail -1 | cut -f1)"'
    echo
    echo "and the multi-stage image, for comparison:"
    docker run --rm ana-ms-multi sh -c \
      'echo "  node_modules : $(du -sh node_modules 2>/dev/null | cut -f1)";
       echo "  esbuild bin  : $(ls node_modules/@esbuild 2>/dev/null || echo "not present")";
       echo "  files in /srv: $(ls)"'

    echo
    echo "\$ docker run -d --name ana-ms-multi -p 8090:3000 ana-ms-multi"
    docker rm -f ana-ms-multi >/dev/null 2>&1
    docker run -d --name ana-ms-multi -p 8090:3000 ana-ms-multi >/dev/null
    for _ in $(seq 1 30); do curl -sf -o /dev/null --max-time 1 http://localhost:8090/ && break; done
    printf 'HTTP %s from http://localhost:8090/\n' \
        "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8090/)"
    curl -s http://localhost:8090/ | grep -E '<h1>|<title>' | sed 's/^ */  /'
    echo "  /health -> $(curl -s http://localhost:8090/health)"
}

# ---------------------------------------------------------------- task 2 ----

# Runs one build with plain progress into a log, then reports, per instruction,
# whether BuildKit reused a cached layer. Reading the raw build output by eye
# does not work: the steps interleave and the CACHED marker for a step can be
# printed several lines after the step itself.
cache_report() {
    local log=$1
    awk '/^#[0-9]+ \[/ { step[$1] = substr($0, index($0, "[")) }
         /^#[0-9]+ CACHED/ { cached[$1] = 1 }
         END {
             for (s in step)
                 printf "  %-9s %s\n", (s in cached ? "CACHED" : "re-ran"), step[s]
         }' "$log" | grep -E 'COPY|RUN' | sort -k2
}

task_cache() {
    section "TASK 2  layers and the build cache"

    echo "--- docker history ana-ms-multi (newest layer first) ---"
    echo
    docker history ana-ms-multi --format 'table {{.Size}}	{{.CreatedBy}}' --no-trunc         | cut -c1-110
    echo
    echo "Only instructions that add files have a size. WORKDIR, ENV, EXPOSE,"
    echo "USER and CMD are metadata: they are layers, but 0 bytes of them."
    echo

    echo "--- experiment A: change the SOURCE only, rebuild ---"
    echo
    cp multi-stage-app/src/page.js /tmp/page.bak
    printf '
// touched by run-all.sh at %s
' "$(date +%s)" >> multi-stage-app/src/page.js
    a0=$(date +%s)
    docker build --progress=plain -t ana-ms-multi multi-stage-app >/tmp/build-a.log 2>&1
    a1=$(date +%s)
    cp /tmp/page.bak multi-stage-app/src/page.js
    cache_report /tmp/build-a.log
    printf '  %s seconds
' "$((a1 - a0))"
    echo
    echo "  npm install was reused in both stages. The manifest did not change,"
    echo "  and it is copied BEFORE the source, so the install layer is untouched."
    echo

    echo "--- experiment B: change PACKAGE.JSON, rebuild ---"
    echo
    cp multi-stage-app/package.json /tmp/pkg.bak
    # A fresh version number every run. Bumping to a fixed "1.0.1" looks like
    # it does nothing the second time you run this script: BuildKit still has
    # the layer it built for 1.0.1 the first time, and reports CACHED for a
    # change it has genuinely already seen.
    sed -i "s/\"version\": \"1.0.0\"/\"version\": \"1.0.$(date +%s)\"/" multi-stage-app/package.json
    b0=$(date +%s)
    docker build --progress=plain -t ana-ms-multi multi-stage-app >/tmp/build-b.log 2>&1
    b1=$(date +%s)
    cp /tmp/pkg.bak multi-stage-app/package.json
    cache_report /tmp/build-b.log
    printf '  %s seconds
' "$((b1 - b0))"
    echo
    echo "  every instruction from the changed COPY downwards re-ran, in both"
    echo "  stages, including two npm installs -- whether or not it had anything"
    echo "  to do with the version number that changed."
    echo
    echo "  full logs: /tmp/build-a.log and /tmp/build-b.log"
}

# ---------------------------------------------------------------- task 3 ----
task_deploy() {
    section "TASK 3  the same service packaged three ways"

    for entry in "${DEPLOYMENTS[@]}"; do
        IFS=';' read -r name dir hp cp <<< "$entry"
        printf '\n--- %s from %s\n' "$name" "$dir"
        if docker build -q -t "$name" "$dir" >/dev/null; then
            docker rm -f "$name" >/dev/null 2>&1
            docker run -d --name "$name" -p "$hp:$cp" "$name" >/dev/null
            printf '  built %s, running on http://localhost:%s\n' "$(size "$name")" "$hp"
        else
            echo "  BUILD FAILED"
        fi
    done

    echo
    for entry in "${DEPLOYMENTS[@]}"; do
        IFS=';' read -r name _ hp _ <<< "$entry"
        for _ in $(seq 1 40); do curl -sf -o /dev/null --max-time 1 "http://localhost:$hp/" && break; done
        printf '  %-18s HTTP %s   %-9s  %s\n' "$name" \
            "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$hp/")" \
            "$(size "$name")" "$(curl -s "http://localhost:$hp/health")"
    done

    echo
    echo "--- what the JDK stage would have cost, if it had shipped ---"
    docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' \
        | grep -E 'REPOSITORY|temurin' || echo "  (base images not pulled separately)"
    echo
    docker ps --filter 'name=ana-deploy-' --filter 'name=ana-ms-' \
        --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
}

# ----------------------------------------------------------------- clean ----
task_clean() {
    section "removing containers"
    for entry in "${DEPLOYMENTS[@]}"; do
        IFS=';' read -r name _ _ _ <<< "$entry"
        docker rm -f "$name" >/dev/null 2>&1 && echo "  removed $name"
    done
    docker rm -f ana-ms-multi >/dev/null 2>&1 && echo "  removed ana-ms-multi"
    echo
    echo "images kept. to remove: docker rmi \$(docker images -q 'ana-*')"
}

if ! docker info >/dev/null 2>&1; then
    echo "the docker daemon is not answering -- start Docker Desktop first."
    exit 1
fi

case "${1:-all}" in
    sizes)  task_sizes ;;
    cache)  task_cache ;;
    deploy) task_deploy ;;
    clean)  task_clean ;;
    all)    task_sizes; task_cache; task_deploy
            section "done"
            echo "  http://localhost:8090   task 1, multi-stage app"
            echo "  http://localhost:8091   task 3, node"
            echo "  http://localhost:8092   task 3, python"
            echo "  http://localhost:8093   task 3, java"
            echo
            echo "  bash run-all.sh clean   when finished"
            ;;
    *)      echo "usage: bash run-all.sh [all|sizes|cache|deploy|clean]"; exit 2 ;;
esac
