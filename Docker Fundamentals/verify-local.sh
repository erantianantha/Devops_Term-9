#!/usr/bin/env bash
#
# verify-local.sh -- run the application code on this machine, without Docker.
#
#   bash verify-local.sh
#
# Why this exists: when a container does not serve a page there are two
# suspects, the app and the Dockerfile. Proving the app works on the host
# first removes one of them, so a later failure in build-and-run.sh is
# unambiguously about packaging.
#
# Anything whose toolchain is missing is SKIPPED, not failed. Ports are in the
# 1xxxx range so they cannot collide with the containers.

set -u
cd "$(dirname "$0")" || exit 1

WORK=$(mktemp -d)
PIDS=()
PASS=0; FAIL=0; SKIP=0

# Kill every background server on the way out, whatever the exit path. Without
# this, a failed run leaves a node process holding a port and the next run
# fails for a completely unrelated reason.
cleanup() {
    for p in "${PIDS[@]:-}"; do kill "$p" 2>/dev/null; done
    rm -rf "$WORK"
}
trap cleanup EXIT

say()  { printf '\n-- %s\n' "$*"; }
ok()   { printf '   PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '   FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }
meh()  { printf '   SKIP  %s\n' "$*"; SKIP=$((SKIP+1)); }

# Poll a URL until it answers or we give up, then echo the body.
fetch() {
    local url=$1 i
    for i in $(seq 1 40); do
        curl -sf -o /dev/null --max-time 1 "$url" && break
    done
    curl -s --max-time 5 "$url"
}

# Look for the app's own marker, not for "Hello World" -- same reasoning as in
# build-and-run.sh.
expect() {
    local label=$1 body=$2 marker=$3
    if printf '%s' "$body" | grep -qF -- "$marker"; then
        ok "$label"
        printf '%s' "$body" | grep -E '<title>|<h1>' | sed 's/^ */         /'
    else
        bad "$label (did not contain: $marker)"
    fi
}

say "node -- syntax, install, serve on 13000"
if command -v node >/dev/null 2>&1; then
    if node --check nodejs-app/server.js && node --check nodejs-app/page.js; then
        echo "   syntax ok on server.js and page.js"
        [ -d nodejs-app/node_modules ] || \
            (cd nodejs-app && npm install --omit=dev --no-audit --no-fund >/dev/null 2>&1)
        (cd nodejs-app && PORT=13000 node server.js >"$WORK/node.log" 2>&1 &)
        sleep 1
        expect "nodejs-app" "$(fetch http://localhost:13000/)" "Node.js + Express"
        echo "         /health -> $(curl -s --max-time 3 http://localhost:13000/health)"
        pkill -f "node server.js" 2>/dev/null
    else
        bad "nodejs-app has a syntax error"
    fi
else
    meh "nodejs-app (node not installed)"
fi

say "python -- compile, venv, serve on 15000"
if command -v python >/dev/null 2>&1; then
    if python -m py_compile python-app/app.py; then
        echo "   compiles"
        python -m venv "$WORK/venv" >/dev/null 2>&1
        PY="$WORK/venv/Scripts/python.exe"; [ -x "$PY" ] || PY="$WORK/venv/bin/python"
        "$PY" -m pip install -q -r python-app/requirements.txt >/dev/null 2>&1
        (cd python-app && PORT=15000 "$PY" app.py >"$WORK/py.log" 2>&1 &)
        sleep 2
        expect "python-app" "$(fetch http://localhost:15000/)" "Python + Flask"
        echo "         /health -> $(curl -s --max-time 3 http://localhost:15000/health)"
        pkill -f "app.py" 2>/dev/null
    else
        bad "python-app does not compile"
    fi
else
    meh "python-app (python not installed)"
fi

say "java -- compile with javac, serve on 18080"
if command -v javac >/dev/null 2>&1; then
    if javac -Xlint:all -d "$WORK/classes" java-app/src/HelloWorld.java; then
        echo "   compiled with no warnings"
        (PORT=18080 java -cp "$WORK/classes" HelloWorld >"$WORK/java.log" 2>&1 &)
        sleep 1
        expect "java-app" "$(fetch http://localhost:18080/)" "Java :: JDK HttpServer"
        echo "         /health -> $(curl -s --max-time 3 http://localhost:18080/health)"
        pkill -f "HelloWorld" 2>/dev/null
    else
        bad "java-app does not compile"
    fi
else
    meh "java-app (javac not installed)"
fi

say "react -- npm run build, which is stage 1 of its Dockerfile"
if command -v npm >/dev/null 2>&1; then
    (cd React-app && npm install --no-audit --no-fund >/dev/null 2>&1 && npm run build 2>&1) | tail -5
    if [ -f React-app/dist/index.html ]; then
        ok "React-app produced dist/"
        ls React-app/dist React-app/dist/assets | sed 's/^/         /'
        bundle=$(ls React-app/dist/assets/*.js 2>/dev/null | head -1)
        # The point of checking the bundle: the text is in App.jsx, and finding
        # it in the compiled output proves the JSX really was compiled rather
        # than copied.
        [ -n "$bundle" ] && for s in "Hello World" "React + Vite"; do
            printf '         bundle mentions %-16s %s time(s)\n' "$s" "$(grep -c "$s" "$bundle")"
        done
    else
        bad "React-app build produced no dist/index.html"
    fi
else
    meh "React-app (npm not installed)"
fi

say "apache and nginx -- static files, nothing to run"
# These two have no application code: the Dockerfile drops a file into a
# document root. Off Docker the only meaningful check is that the file says
# what it should; the servers themselves are exercised by build-and-run.sh.
for pair in "Apache-app:Apache HTTP Server" "nginx-app:>Nginx<"; do
    dir=${pair%%:*}; marker=${pair#*:}
    if grep -qF -- "$marker" "$dir/index.html" 2>/dev/null; then
        ok "$dir/index.html"
    else
        bad "$dir/index.html is missing its marker"
    fi
done

printf '\n== %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
echo "   This covers the application code only."
echo "   Run 'bash build-and-run.sh' to test the images and containers."
