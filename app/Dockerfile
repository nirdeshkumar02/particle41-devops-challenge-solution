# Stage 1 — install dependencies
FROM python:3.13-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2 — minimal final image
FROM python:3.13-slim AS final

WORKDIR /app

# Create a non-root user
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application code
COPY main.py .

USER appuser

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
