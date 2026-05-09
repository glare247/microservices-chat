FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    APP_HOME=/microservice/ \
    CONFIGMAP_FILE=/microservice/config-docker.yml

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p $APP_HOME && \
    addgroup --system appgroup && \
    adduser --system --ingroup appgroup python && \
    chown -R python $APP_HOME

WORKDIR $APP_HOME

COPY requirements*.txt $APP_HOME
RUN pip install --upgrade pip setuptools wheel==0.46.2 && \
    pip install --no-cache-dir -r requirements-docker.txt

COPY . $APP_HOME

USER python

EXPOSE 8080

HEALTHCHECK --interval=30s \
            --timeout=10s \
            --start-period=30s \
            --retries=3 \
  CMD python -c \
  "import urllib.request; \
   urllib.request.urlopen('http://localhost:8080/health')" \
  || exit 1

CMD ["gunicorn", \
     "--worker-class", "eventlet", \
     "--workers", "1", \
     "--log-level", "INFO", \
     "--bind", "0.0.0.0:8080", \
     "manage:app"]