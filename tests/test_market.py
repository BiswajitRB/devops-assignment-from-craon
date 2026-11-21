from fastapi.testclient import TestClient
from app.main import app
from app.services.exchange_service import ExchangeService

client = TestClient(app)

def test_ticker(monkeypatch):
    # Mock external exchange API for deterministic offline unit testing
    def mock_get_ticker(self, symbol):
        return {
            "symbol": symbol,
            "bid": 65000.0,
            "ask": 65010.0,
            "last": 65005.0,
        }
    monkeypatch.setattr(ExchangeService, "get_ticker", mock_get_ticker)

    response = client.get("/ticker?symbol=BTC/USDT")
    assert response.status_code == 200
    assert "data" in response.json()
    assert response.json()["data"]["symbol"] == "BTC/USDT"
