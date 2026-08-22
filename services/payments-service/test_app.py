"""Minimal smoke test — run with: pytest test_app.py (used by CI)."""
from fastapi.testclient import TestClient


def test_health_endpoint_shape():
    from app import app
    client = TestClient(app)
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
