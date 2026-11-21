from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app, raise_server_exceptions=False)

def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert "endpoints" in response.json()

def test_health():
    response = client.get("/health")
    assert response.status_code in [200, 503]
    data = response.json()
    assert "status" in data
    assert "checks" in data

def test_metrics():
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "http_requests" in response.text or "process_" in response.text or "python_" in response.text

def test_simulate_500():
    response = client.get("/simulate-500")
    assert response.status_code == 500
    assert "Internal Server Error" in response.text or "error" in response.text
