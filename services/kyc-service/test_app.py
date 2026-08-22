"""Minimal smoke test — run with: pytest test_app.py (used by CI)."""
from fastapi.testclient import TestClient


def test_health_endpoint_shape():
    # Import here so missing DB/Redis at collection time doesn't break `pytest --collect-only`
    from app import app
    client = TestClient(app)
    # NOTE: /health doesn't touch the DB, so this passes even without docker-compose running.
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
