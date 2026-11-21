# app/main.py

import time
import uuid
import json
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, Request, Response
from fastapi.responses import FileResponse, JSONResponse
try:
    from prometheus_fastapi_instrumentator import Instrumentator
    HAS_PROMETHEUS = True
except ImportError:
    HAS_PROMETHEUS = False

from app.api.routes import market, historical, health
from app.websocket.stream import stream_prices
from app.services.db_service import DatabaseService

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("crypto.api")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Connect to MongoDB
    logger.info("Initializing database connection...")
    DatabaseService.connect()
    yield
    # Shutdown
    if DatabaseService.client:
        DatabaseService.client.close()
        logger.info("Database connection closed.")

app = FastAPI(
    title="MCP Crypto Server - DevOps Edition",
    description="Real-Time Crypto Market Data Server with MongoDB Persistence & Prometheus Observability",
    version="1.0.0",
    lifespan=lifespan,
)

# Observability Middleware: Structured JSON Access Logging with Request ID
@app.middleware("http")
async def structured_json_logging_middleware(request: Request, call_next):
    request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
    start_time = time.time()

    try:
        response: Response = await call_next(request)
        duration_ms = round((time.time() - start_time) * 1000, 2)
        response.headers["x-request-id"] = request_id

        log_payload = {
            "level": "info",
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status": response.status_code,
            "duration_ms": duration_ms,
            "client_ip": request.client.host if request.client else "unknown",
        }
        logger.info(json.dumps(log_payload))
        return response
    except Exception as exc:
        duration_ms = round((time.time() - start_time) * 1000, 2)
        log_payload = {
            "level": "error",
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "status": 500,
            "duration_ms": duration_ms,
            "error": str(exc),
        }
        logger.error(json.dumps(log_payload))
        return JSONResponse(
            status_code=500,
            content={"error": "Internal Server Error", "request_id": request_id, "detail": str(exc)},
            headers={"x-request-id": request_id},
        )

# Prometheus Metric Exposition (/metrics)
if HAS_PROMETHEUS:
    Instrumentator().instrument(app).expose(app, endpoint="/metrics")
else:
    @app.get("/metrics")
    def fallback_metrics():
        return Response(
            content="# HELP http_requests_total Total HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total 1\n",
            media_type="text/plain",
        )

# Include API routes
app.include_router(market.router)
app.include_router(historical.router)
app.include_router(health.router)

# Root endpoint
@app.get("/")
def root():
    return {
        "message": "MCP Crypto Server Running 🚀",
        "endpoints": {
            "graph_ui": "/graph",
            "health": "/health",
            "metrics": "/metrics",
            "ticker": "/ticker?symbol=BTC/USDT",
            "watchlist": "/watchlist",
            "simulate_incident": "/simulate-500",
        },
    }

# Serve Graph UI
@app.get("/graph")
def get_graph():
    return FileResponse("app/static/index.html")

# WebSocket for real-time market data
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, symbol: str = "BTC/USDT", exchange: str = "binance"):
    await stream_prices(websocket, symbol, exchange)
