# Nginx -----------------------------------------------------------------------
# Demonstrates: an image that is pure configuration, and nginx's own paths.

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

# Catch a bad config while building instead of discovering it as a container
# that dies immediately after `docker run`.
RUN nginx -t

EXPOSE 80

# Inherited: CMD ["nginx", "-g", "daemon off;"]
# "daemon off" plays the same role here that httpd-foreground plays in the
# Apache image. Left to itself nginx forks a master into the background and
# the foreground process returns, at which point Docker declares the container
# finished.
