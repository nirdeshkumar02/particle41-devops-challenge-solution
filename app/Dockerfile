FROM python:3.12-alpine AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-alpine AS final

WORKDIR /app

RUN adduser -D -u 1000 -s /bin/sh nirdesh

COPY --from=builder /install /usr/local

COPY --chown=nirdesh:nirdesh main.py .

RUN chown nirdesh:nirdesh /app && chmod 700 /app && chmod 600 /app/main.py

USER nirdesh

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO /dev/null http://localhost:8080/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
