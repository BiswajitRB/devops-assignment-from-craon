# app/websocket/stream.py

import asyncio
import logging
from fastapi import WebSocket, WebSocketDisconnect
from app.services.exchange_service import ExchangeService

logger = logging.getLogger("crypto.ws")

async def stream_prices(websocket: WebSocket, symbol: str = "BTC/USDT", exchange: str = "binance"):
    await websocket.accept()
    try:
        service = ExchangeService(exchange)
    except Exception as e:
        logger.error(f"Invalid exchange {exchange}: {e}")
        await websocket.close()
        return

    try:
        while True:
            # Offload synchronous ccxt network request to threadpool to avoid blocking asyncio event loop
            try:
                data = await asyncio.to_thread(service.get_ticker, symbol)
                await websocket.send_json(data)
            except Exception as err:
                logger.warning(f"Ticker fetch error in stream: {err}")
            await asyncio.sleep(2)
    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected by client for {symbol}")
    except Exception as e:
        logger.error(f"WebSocket exception: {e}")
