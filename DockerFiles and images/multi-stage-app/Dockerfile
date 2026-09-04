# Task 1 - multi-stage build
# =============================================================================
# Stage 1 "builder": installs EVERY dependency, including devDependencies,
#   and runs the bundle step. esbuild alone is ~10MB of platform binary.
# Stage 2 "runtime": starts from a clean base, installs production
#   dependencies only, and copies one file out of stage 1.
#
# Compare with Dockerfile.single next door, which does the same work in one
# stage. Both serve the identical page; only one of them ships a bundler.
# =============================================================================

FROM node:20-alpine AS builder
WORKDIR /build

# Manifests first: this layer is reused until package.json itself changes.
COPY package.json ./
RUN npm install --no-audit --no-fund

COPY build.js ./
COPY src ./src
RUN npm run build

# Fail here, loudly, if the bundle did not appear. Without this the next stage
# would copy nothing and produce an image that starts and immediately exits.
RUN test -s dist/bundle.js && wc -c dist/bundle.js

# -----------------------------------------------------------------------------

FROM node:20-alpine AS runtime
WORKDIR /srv

# --omit=dev is the second half of the saving. The builder needed esbuild;
# this image needs Express and nothing else.
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund && npm cache clean --force

# The one line the pattern exists for.
COPY --from=builder /build/dist/bundle.js ./bundle.js

ENV NODE_ENV=production PORT=3000
EXPOSE 3000
USER node
CMD ["node", "bundle.js"]
