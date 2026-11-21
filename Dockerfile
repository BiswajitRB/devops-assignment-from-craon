# ==============================================================================
# Stage 1: Build & Dependencies Resolution (Builder)
# ==============================================================================
FROM python:3.11-slim AS builder

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install compiler dependencies for C-extensions
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc build-essential && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Install dependencies into /install folder
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ==============================================================================
# Stage 2: Minimal Distroless Runtime Image
# Google Distroless Python image contains ONLY Python and essential C runtimes.
# It has NO package manager (apt/pip), NO shell (bash/sh), and runs as nonroot.
# ==============================================================================
FROM gcr.io/distroless/python3-debian12:nonroot AS runner

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/usr/local/lib/python3.11/site-packages:/app \
    PORT=8000 \
    HOST=0.0.0.0

# Copy installed dependencies from builder
COPY --from=builder /install /usr/local

# Copy application code
COPY --chown=nonroot:nonroot . .

# Run as non-root user (UID 65532)
USER nonroot

EXPOSE 8000

# Container healthcheck: native python probe without curl or wget
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["python3", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]

# Direct executable invocation (exec form)
CMD ["/usr/local/bin/uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
