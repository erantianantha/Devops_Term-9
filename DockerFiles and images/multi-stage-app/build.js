// The "build" this app has, so that a build stage is a real stage and not a
// pretend one. esbuild bundles src/app.js and its imports into a single
// dist/bundle.js; after that the app runs with only Express installed and
// esbuild (about 10MB of platform binary) is not needed again.
//
// This is the honest version of the multi-stage argument: the point is not
// that two FROMs are tidy, it is that the build needs tools the runtime does
// not, and those tools should not ship.
const esbuild = require('esbuild');

esbuild
  .build({
    entryPoints: ['src/app.js'],
    bundle: true,
    platform: 'node',
    target: 'node20',
    outfile: 'dist/bundle.js',
    // Express stays external: it is a runtime dependency, installed in the
    // runtime stage. Bundling it in would work but would hide the dependency
    // from `npm ls` and from any scanner reading package.json.
    external: ['express'],
    logLevel: 'info',
  })
  .catch(() => process.exit(1));
