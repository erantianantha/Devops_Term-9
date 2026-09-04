// Task 3, Node deployment. Same contract as the Python and Java ones:
// GET /        an HTML card describing the image it is running in
// GET /health  {"ok":true,...}
const express = require('express');
const os = require('os');

const PORT = Number(process.env.PORT) || 3000;
const FACTS = {
  stack: 'Node 20 + Express',
  base: 'node:20-alpine',
  builder: 'node:20-alpine (dev deps installed, then discarded)',
  artefact: 'node_modules built in stage 1, copied to stage 2',
};

const card = () => `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>deploy :: node</title>
<style>
 body{margin:0;min-height:100vh;display:grid;place-items:center;background:#f4f1ea;color:#1f2124;
      font-family:"Segoe UI",system-ui,sans-serif}
 .card{background:#fff;border:1px solid #d9d3c7;border-radius:10px;padding:2rem 2.4rem;
       box-shadow:0 10px 30px rgba(0,0,0,.07);min-width:24rem}
 h1{margin:0 0 .2rem;font-size:1.9rem}
 .tag{font-size:.75rem;letter-spacing:.12em;text-transform:uppercase;color:#5d8c46;font-weight:700}
 dl{display:grid;grid-template-columns:auto 1fr;gap:.35rem 1rem;font-size:.88rem;margin-top:1.3rem}
 dt{color:#6b6b6b} dd{margin:0;font-family:Consolas,monospace}
</style></head><body><main class="card">
<span class="tag">deployment 1 of 3</span>
<h1>Node</h1>
<dl>
${Object.entries(FACTS).map(([k, v]) => `  <dt>${k}</dt><dd>${v}</dd>`).join('\n')}
  <dt>container</dt><dd>${os.hostname()}</dd>
  <dt>port</dt><dd>${PORT}</dd>
</dl></main></body></html>`;

const app = express();
app.get('/', (_q, r) => r.type('html').send(card()));
app.get('/health', (_q, r) => r.json({ ok: true, stack: 'node', host: os.hostname() }));
app.listen(PORT, '0.0.0.0', () => console.log(`[node] listening on 0.0.0.0:${PORT}`));
