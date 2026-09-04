# Node.js + Express -----------------------------------------------------------
# Demonstrates: build-cache ordering, a non-root runtime user, HEALTHCHECK.

FROM node:20-alpine

# Alpine's package index is only needed for the healthcheck tool. Adding wget
# in one layer and cleaning the index in the same RUN keeps the layer small —
# a separate `rm` in a later instruction would not shrink anything, because the
# files are already committed to the earlier layer.
RUN apk add --no-cache wget

WORKDIR /srv/app

# Manifests first. Docker caches per instruction and re-runs an instruction
# only when its inputs change, so putting the dependency install above the
# source copy means editing server.js does NOT reinstall Express.
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

# Source last: this is the layer that changes on every edit.
COPY server.js page.js ./

# Purely declarative. EXPOSE publishes nothing — `docker run -p` does that.
# It documents the contract for whoever reads the image later.
EXPOSE 3000

# The container reports its own health, so `docker ps` can say "healthy"
# instead of just "up". --start-period stops the first few probes counting
# against the container while it is still booting.
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1:3000/health || exit 1

# node:alpine ships an unprivileged user called `node`. Using it means a
# process that gets compromised is not root inside the container.
USER node

# Exec form, so node becomes PID 1 and receives SIGTERM from `docker stop`
# directly. In shell form node is a child of /bin/sh, the signal goes to the
# shell instead, and every stop waits the full 10-second grace period.
CMD ["node", "server.js"]
