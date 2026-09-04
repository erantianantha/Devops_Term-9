# Task 3 - Node deployment, multi-stage.
#
# The build stage exists to keep npm's cache, its temporary files and any
# devDependency out of the runtime image. The runtime stage receives a
# node_modules tree that was resolved once and is copied whole, so the runtime
# image never talks to a registry.
FROM node:20-alpine AS deps
WORKDIR /deps
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund

FROM node:20-alpine
WORKDIR /srv
COPY --from=deps /deps/node_modules ./node_modules
COPY package.json server.js ./
ENV NODE_ENV=production PORT=3000
EXPOSE 3000
USER node
CMD ["node", "server.js"]
