import { useEffect, useState } from 'react';

// Two pieces of live behaviour, both deliberate:
//
//  - a counter, which only a running JS bundle can do; a screenshot of it at
//    a non-zero value is proof the build produced working JavaScript.
//  - a fetch of /health, which is served by the SAME nginx that serves this
//    page. If it renders, the container's own config is answering.
export default function App() {
  const [clicks, setClicks] = useState(0);
  const [health, setHealth] = useState('checking…');

  useEffect(() => {
    fetch('/health')
      .then((r) => (r.ok ? r.text() : Promise.reject(r.status)))
      .then((t) => setHealth(t.trim()))
      .catch((e) => setHealth(`unreachable (${e})`));
  }, []);

  return (
    <main className="card">
      <span className="stack">React + Vite</span>
      <h1>Hello World</h1>
      <p>Bundled by Node in stage one, served by nginx in stage two.</p>

      <dl>
        <dt>built with</dt>
        <dd>vite {import.meta.env.MODE} build</dd>
        <dt>/health says</dt>
        <dd>{health}</dd>
      </dl>

      <button onClick={() => setClicks((n) => n + 1)}>
        clicked {clicks} {clicks === 1 ? 'time' : 'times'}
      </button>
    </main>
  );
}
