# Stage 1 — install dependencies
FROM python:3.13-alpine AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2 — minimal final image
FROM python:3.13-alpine AS final

WORKDIR /app

# Create a non-root user
RUN adduser -D -u 1001 -s /bin/sh nirdesh

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application code with nirdesh ownership
COPY --chown=nirdesh:nirdesh main.py .

# Transfer ownership and restrict /app directory to nirdesh only
RUN chown nirdesh:nirdesh /app && chmod 700 /app && chmod 600 /app/main.py

USER nirdesh

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
