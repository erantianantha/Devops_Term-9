"""Hello World service in Flask.

Written with the application-factory pattern (create_app) rather than a
module-level app = Flask(__name__).  It costs three extra lines and buys two
things: the app can be built with different settings for a test, and nothing
runs at import time, so importing this module cannot accidentally start a web
server.
"""

from __future__ import annotations

import os
import platform
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template_string

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Hello World :: Python</title>
<style>
  :root { color-scheme: light; }
  body { margin: 0; min-height: 100vh; display: grid; place-items: center;
         background: #f4f1ea; color: #1f2124;
         font-family: "Segoe UI", system-ui, sans-serif; }
  .card { background: #fff; border: 1px solid #d9d3c7; border-radius: 10px;
          padding: 2rem 2.5rem; box-shadow: 0 10px 30px rgba(0,0,0,.07);
          max-width: 30rem; }
  h1 { margin: 0 0 .25rem; font-size: 2.4rem; letter-spacing: -.02em; }
  .stack { font-size: .8rem; text-transform: uppercase; letter-spacing: .12em;
           color: #2b5b84; font-weight: 700; }
  dl { display: grid; grid-template-columns: auto 1fr; gap: .35rem 1rem;
       margin: 1.5rem 0 0; font-size: .9rem; }
  dt { color: #6b6b6b; }
  dd { margin: 0; font-family: Consolas, "Courier New", monospace; }
</style>
</head>
<body>
  <main class="card">
    <span class="stack">Python + Flask</span>
    <h1>Hello World</h1>
    <p>Rendered by Flask inside a container built from python:3.12-slim.</p>
    <dl>
      <dt>listening on</dt><dd>0.0.0.0:{{ port }}</dd>
      <dt>container id</dt><dd>{{ host }}</dd>
      <dt>interpreter</dt><dd>{{ python }}</dd>
      <dt>libc / os</dt><dd>{{ libc }}</dd>
      <dt>served at</dt><dd>{{ now }}</dd>
    </dl>
  </main>
</body>
</html>
"""


def create_app(port: int) -> Flask:
    app = Flask(__name__)

    @app.get("/")
    def index() -> str:
        # platform.libc_ver() is here on purpose: it reports glibc on the
        # -slim image and would report nothing useful on Alpine, which is the
        # practical reason this Dockerfile avoids Alpine.
        libc_name, libc_version = platform.libc_ver()
        return render_template_string(
            PAGE,
            port=port,
            host=socket.gethostname(),
            python=platform.python_version(),
            libc=(libc_name + " " + libc_version).strip() or "musl",
            now=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ"),
        )

    @app.get("/health")
    def health():
        return jsonify(ok=True, service="python", host=socket.gethostname())

    return app


if __name__ == "__main__":
    PORT = int(os.environ.get("PORT", "5000"))
    # host="0.0.0.0" is mandatory in a container. Flask defaults to 127.0.0.1,
    # which binds the container own loopback only, and then a perfectly
    # correct -p 5000:5000 still gives "Empty reply from server".
    create_app(PORT).run(host="0.0.0.0", port=PORT)
