# Python + Flask --------------------------------------------------------------
# Demonstrates: why -slim beats -alpine for Python, unbuffered logging,
# dropping root before CMD.

# python:3.12-alpine is tempting because it is tiny, but Alpine links against
# musl instead of glibc and PyPI ships manylinux wheels built for glibc. Any
# dependency with a C extension therefore compiles from source on Alpine.
# Flask alone is pure Python and would be fine, but the moment this app grows
# a real dependency the build time goes from seconds to minutes.
FROM python:3.12-slim

# PYTHONUNBUFFERED: without it stdout is block-buffered when it is not a
#   terminal, and `docker logs` shows nothing until several KB have piled up.
#   The container looks hung when it is working perfectly.
# PYTHONDONTWRITEBYTECODE: .pyc files in an image are dead weight; the layer
#   is read-only and the cache dies with the container.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=5000

WORKDIR /srv/app

# Dependency manifest before source, same cache argument as the Node image.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./

# The python images have no ready-made unprivileged user, so make one.
# --system skips the password ageing and mail spool a login account would get.
RUN adduser --system --no-create-home --group flaskuser
USER flaskuser

EXPOSE 5000

CMD ["python", "app.py"]
