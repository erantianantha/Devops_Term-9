// A separate module purely so the bundle step has something to do: esbuild
// has to resolve this import and inline it into dist/bundle.js.
const os = require('os');

exports.render = (port) => `<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Multi-stage build</title>
<style>
 body{margin:0;min-height:100vh;display:grid;place-items:center;background:#f4f1ea;
      color:#1f2124;font-family:"Segoe UI",system-ui,sans-serif}
 .card{background:#fff;border:1px solid #d9d3c7;border-radius:10px;padding:2rem 2.5rem;
       box-shadow:0 10px 30px rgba(0,0,0,.07)}
 h1{margin:0 0 .3rem;font-size:2.2rem}
 code{font-family:Consolas,monospace;background:#f0ece3;padding:.1rem .3rem;border-radius:3px}
 dl{display:grid;grid-template-columns:auto 1fr;gap:.35rem 1rem;font-size:.9rem;margin-top:1.4rem}
 dt{color:#6b6b6b} dd{margin:0;font-family:Consolas,monospace}
</style></head>
<body><main class="card">
<h1>Hello from a multi-stage build</h1>
<p>This response comes from <code>dist/bundle.js</code>, produced by esbuild in a
   stage that is not part of this image.</p>
<dl>
  <dt>container</dt><dd>${os.hostname()}</dd>
  <dt>listening</dt><dd>0.0.0.0:${port}</dd>
  <dt>node</dt><dd>${process.version}</dd>
  <dt>entry point</dt><dd>${require.main ? require.main.filename : 'bundle'}</dd>
</dl>
</main></body></html>`;
