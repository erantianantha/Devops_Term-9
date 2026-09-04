# React (Vite) :: multi-stage -------------------------------------------------
# Demonstrates: the build toolchain never reaching the shipped image.
#
# A React app is not something a server executes. `vite build` turns JSX and
# ES modules into plain HTML/CSS/JS, and from that point Node is irrelevant.
# So stage one installs ~200MB of node_modules and produces /app/dist, and
# stage two takes /app/dist and nothing else.

FROM node:20-alpine AS bundler
WORKDIR /app

# Manifest first so the install layer survives edits to the components.
COPY package.json ./
RUN npm install --no-audit --no-fund

COPY vite.config.js index.html ./
COPY src ./src
RUN npm run build

# Fail the build here rather than at runtime if the bundle did not appear.
# A missing dist/ would otherwise produce an image that starts fine and
# serves nginx's default page.
RUN test -f /app/dist/index.html

FROM nginx:1.27-alpine
COPY --from=bundler /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Syntax-check the config at build time. Shipping a broken nginx.conf means a
# container that exits one second after it starts, and the reason is only in
# `docker logs`.
RUN nginx -t

EXPOSE 80
# CMD ["nginx", "-g", "daemon off;"] comes from the base image.
