// The HTML lives in its own module so server.js stays about routing and the
// page stays about markup. Keeping them apart also means editing the page does
// not force me to re-read the server logic every time.
const os = require('os');

const CARD_CSS = `
  :root { color-scheme: light; }
  body { margin: 0; min-height: 100vh; display: grid; place-items: center;
         background: #f4f1ea; color: #1f2124;
         font-family: "Segoe UI", system-ui, sans-serif; }
  .card { background: #fff; border: 1px solid #d9d3c7; border-radius: 10px;
          padding: 2rem 2.5rem; box-shadow: 0 10px 30px rgba(0,0,0,.07);
          max-width: 30rem; }
  h1 { margin: 0 0 .25rem; font-size: 2.4rem; letter-spacing: -.02em; }
  .stack { font-size: .8rem; text-transform: uppercase; letter-spacing: .12em;
           color: #5d8c46; font-weight: 700; }
  dl { display: grid; grid-template-columns: auto 1fr; gap: .35rem 1rem;
       margin: 1.5rem 0 0; font-size: .9rem; }
  dt { color: #6b6b6b; }
  dd { margin: 0; font-family: Consolas, "Courier New", monospace; }
`;

/**
 * Build the landing page.
 * @param {number} port  the port the process is actually listening on
 */
function landingPage(port) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Hello World :: Node.js</title>
<style>${CARD_CSS}</style>
</head>
<body>
  <main class="card">
    <span class="stack">Node.js + Express</span>
    <h1>Hello World</h1>
    <p>This response was generated inside a container, not read off a disk.</p>
    <dl>
      <dt>listening on</dt><dd>0.0.0.0:${port}</dd>
      <dt>container id</dt><dd>${os.hostname()}</dd>
      <dt>node runtime</dt><dd>${process.version}</dd>
      <dt>platform</dt><dd>${process.platform}/${process.arch}</dd>
      <dt>uptime</dt><dd>${process.uptime().toFixed(1)}s</dd>
    </dl>
  </main>
</body>
</html>`;
}

module.exports = { landingPage };
