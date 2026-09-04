# Apache httpd ----------------------------------------------------------------
# Demonstrates: the shortest kind of image there is, plus where the config
# lives and why the server has to stay in the foreground.

FROM httpd:2.4-alpine

# Apache's document root inside this image. Note it is NOT the same path as
# nginx uses (/usr/share/nginx/html) - mixing the two up is the classic
# "why is my page a 404" mistake when switching between the two servers.
COPY index.html health.txt /usr/local/apache2/htdocs/

# Custom config. The stock httpd.conf has a commented-out Include for
# conf/extra, so instead of editing the main file I append one line to it and
# ship my snippet alongside. mod_headers has to be switched on for the
# Header directive in that snippet to be legal.
COPY extra.conf /usr/local/apache2/conf/extra/hello.conf
RUN sed -i 's|^#LoadModule headers_module|LoadModule headers_module|' \
        /usr/local/apache2/conf/httpd.conf \
 && echo "Include conf/extra/hello.conf" >> /usr/local/apache2/conf/httpd.conf \
 && httpd -t

EXPOSE 80

# No CMD. The base image ends with CMD ["httpd-foreground"] and that is
# inherited. The -foreground part is the container-relevant bit: a normal
# httpd daemonises, the parent exits, and Docker would treat that as the main
# process finishing and stop the container immediately.
