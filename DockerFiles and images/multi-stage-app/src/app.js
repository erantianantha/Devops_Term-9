const express = require('express');
const { render } = require('./page');

const PORT = Number(process.env.PORT) || 3000;
const app = express();

app.get('/', (_req, res) => res.type('html').send(render(PORT)));
app.get('/health', (_req, res) => res.json({ ok: true, build: 'multi-stage' }));

app.listen(PORT, '0.0.0.0', () => console.log(`multi-stage app on 0.0.0.0:${PORT}`));
