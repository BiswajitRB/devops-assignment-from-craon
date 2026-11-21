# app/api/routes/market.py

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.services.exchange_service import ExchangeService
from app.services.cache_service import ticker_cache, CacheService
from app.services.db_service import DatabaseService

router = APIRouter()

class WatchlistRequest(BaseModel):
    symbol: str
    notes: str = ""

@router.get("/ticker")
def get_ticker(symbol: str = "BTC/USDT", exchange: str = "binance"):
    key = f"{exchange}:{symbol}:ticker"

    cached = CacheService.get(ticker_cache, key)
    if cached:
        return {"source": "cache", "data": cached}

    try:
        service = ExchangeService(exchange)
        data = service.get_ticker(symbol)
        CacheService.set(ticker_cache, key, data)
        # Asynchronously persist ticker snapshot to MongoDB
        DatabaseService.save_ticker(symbol, exchange, data)
        return {"source": "api", "data": data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/watchlist")
def get_watchlist():
    items = DatabaseService.get_watchlist()
    return {"watchlist": items}

@router.post("/watchlist")
def add_to_watchlist(req: WatchlistRequest):
    result = DatabaseService.add_to_watchlist(req.symbol, req.notes)
    return result
