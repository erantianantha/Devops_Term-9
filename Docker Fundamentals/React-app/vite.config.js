import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// outDir is spelled out even though 'dist' is the default, because the second
// stage of the Dockerfile copies from exactly this path. If the two ever drift
// apart the build still succeeds and the site 404s, which is a slow bug to
// find.
export default defineConfig({
  plugins: [react()],
  build: { outDir: 'dist', sourcemap: false },
});
