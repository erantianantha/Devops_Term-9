"""Task 3, Python deployment. Same two routes as the Node and Java ones."""

import os
import socket

from flask import Flask, jsonify

PORT = int(os.environ.get("PORT", "5000"))

FACTS = {
    "stack": "Python 3.12 + Flask",
    "base": "python:3.12-slim",
    "builder": "python:3.12-slim with build-essential, discarded",
    "artefact": "a wheelhouse built in stage 1, installed in stage 2",
}

app = Flask(__name__)


@app.get("/")
def card():
    rows = "\n".join(f"  <dt>{k}</dt><dd>{v}</dd>" for k, v in FACTS.items())
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>deploy :: python</title>
<style>
 body{{margin:0;min-height:100vh;display:grid;place-items:center;background:#f4f1ea;color:#1f2124;
      font-family:"Segoe UI",system-ui,sans-serif}}
 .card{{background:#fff;border:1px solid #d9d3c7;border-radius:10px;padding:2rem 2.4rem;
       box-shadow:0 10px 30px rgba(0,0,0,.07);min-width:24rem}}
 h1{{margin:0 0 .2rem;font-size:1.9rem}}
 .tag{{font-size:.75rem;letter-spacing:.12em;text-transform:uppercase;color:#2b5b84;font-weight:700}}
 dl{{display:grid;grid-template-columns:auto 1fr;gap:.35rem 1rem;font-size:.88rem;margin-top:1.3rem}}
 dt{{color:#6b6b6b}} dd{{margin:0;font-family:Consolas,monospace}}
</style></head><body><main class="card">
<span class="tag">deployment 2 of 3</span>
<h1>Python</h1>
<dl>
{rows}
  <dt>container</dt><dd>{socket.gethostname()}</dd>
  <dt>port</dt><dd>{PORT}</dd>
</dl></main></body></html>"""


@app.get("/health")
def health():
    return jsonify(ok=True, stack="python", host=socket.gethostname())


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT)
