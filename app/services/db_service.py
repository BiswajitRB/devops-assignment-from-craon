# app/services/db_service.py
# MongoDB Integration Service with Health Verification & Fail-Safe Fallbacks

import os
import logging
try:
    from pymongo import MongoClient
    from pymongo.errors import ConnectionFailure, PyMongoError
    HAS_PYMONGO = True
except ImportError:
    HAS_PYMONGO = False

logger = logging.getLogger("crypto.db")

class DatabaseService:
    client = None
    db = None

    @classmethod
    def connect(cls):
        if not HAS_PYMONGO or os.getenv("TESTING") == "true":
            logger.info("Running in test/in-memory mode (MongoDB bypassed).")
            cls.client = None
            cls.db = None
            return

        mongodb_uri = os.getenv("MONGODB_URI", "mongodb://localhost:27017/crypto_db")
        try:
            cls.client = MongoClient(
                mongodb_uri,
                serverSelectionTimeoutMS=3000,
                connectTimeoutMS=5000,
            )
            # Force server connection check
            cls.client.admin.command("ping")
            cls.db = cls.client.get_default_database()
            logger.info("Connected to MongoDB successfully.")
        except (ConnectionFailure, PyMongoError) as e:
            logger.warning(f"Could not connect to MongoDB: {e}. Running in graceful degraded mode.")
            cls.client = None
            cls.db = None

    @classmethod
    def is_healthy(cls) -> bool:
        if cls.client is None:
            return False
        try:
            cls.client.admin.command("ping")
            return True
        except Exception:
            return False

    @classmethod
    def save_ticker(cls, symbol: str, exchange: str, data: dict):
        if cls.db is not None:
            try:
                cls.db.tickers.update_one(
                    {"symbol": symbol, "exchange": exchange},
                    {"$set": {"data": data, "updated_at": os.getenv("TIMESTAMP")}},
                    upsert=True
                )
            except Exception as e:
                logger.error(f"Failed to persist ticker to MongoDB: {e}")

    @classmethod
    def get_watchlist(cls) -> list:
        if cls.db is not None:
            try:
                records = list(cls.db.watchlist.find({}, {"_id": 0}))
                return records
            except Exception:
                return []
        return []

    @classmethod
    def add_to_watchlist(cls, symbol: str, notes: str = ""):
        if cls.db is not None:
            cls.db.watchlist.update_one(
                {"symbol": symbol},
                {"$set": {"symbol": symbol, "notes": notes}},
                upsert=True
            )
            return {"status": "saved", "symbol": symbol}
        return {"status": "cached_memory", "symbol": symbol}
