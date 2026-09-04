# Task 3 - Python deployment, multi-stage with a wheelhouse.
#
# Stage 1 turns requirements.txt into built wheels. Stage 2 installs from that
# folder with --no-index, so the runtime image never reaches the network and
# never needs a compiler even if a dependency has C extensions. Right now the
# only dependency is Flask, which is pure Python, so the visible saving is
# small -- but this is the shape that stops mattering-later from becoming
# rewriting-later.
FROM python:3.12-slim AS wheels
WORKDIR /wheels
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels/dist -r requirements.txt

FROM python:3.12-slim
WORKDIR /srv
COPY --from=wheels /wheels/dist /tmp/wheels
RUN pip install --no-cache-dir --no-index --find-links=/tmp/wheels Flask \
 && rm -rf /tmp/wheels
COPY app.py .
ENV PYTHONUNBUFFERED=1 PORT=5000
EXPOSE 5000
RUN adduser --system --no-create-home --group svc
USER svc
CMD ["python", "app.py"]
