// Hello World service, Express.
//
// Two routes: the page a human looks at, and a JSON endpoint a script looks at.
// Having both means the container can be checked from a terminal without
// grepping HTML.
const express = require('express');
const os = require('os');
const { landingPage } = require('./page');

const PORT = Number(process.env.PORT) || 3000;
const BIND = '0.0.0.0';           // see the note at the bottom of the file
const startedAt = Date.now();

const app = express();

// One-line request log. Nothing fancy; it exists so `docker logs` shows
// evidence that a request actually arrived, which is the first thing I want
// when a container "isn't responding".
app.use((req, _res, next) => {
  console.log(`${new Date().toISOString()}  ${req.method} ${req.url}`);
  next();
});

app.get('/', (_req, res) => res.type('html').send(landingPage(PORT)));

app.get('/health', (_req, res) =>
  res.json({
    ok: true,
    service: 'nodejs',
    host: os.hostname(),
    uptimeSeconds: Math.round((Date.now() - startedAt) / 1000),
  })
);

app.listen(PORT, BIND, () => console.log(`ana-node up on http://${BIND}:${PORT}`));

// Why BIND is 0.0.0.0 and not localhost:
// a container has its own network namespace. Binding 127.0.0.1 there means
// "only processes inside this container may connect", so `-p 3000:3000` maps a
// host port onto a socket nobody outside can open and curl just hangs up.
// 0.0.0.0 means "every interface this container has", which includes the one
// Docker wired to the host.
