"""
CMST — KYC / Identity service (portfolio demo).

Minimal FastAPI service demonstrating the pattern used for all five
CMST microservices (kyc, circles, lending, arbitration, payments):
- /health for the ALB target-group health check
- a Postgres connection (RDS in AWS, local docker-compose container otherwise)
- a Redis connection for rate limiting / session cache
- a mock KYC verification endpoint
"""
import os
import time
from datetime import datetime, timezone

import psycopg2
import redis
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="CMST KYC Service", version="0.1.0")

DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "cmst")
DB_USER = os.getenv("DB_USER", "cmst_admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "cmst_local_dev_only")

REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)


def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD
    )


class KycRequest(BaseModel):
    user_id: str
    full_name: str
    id_document_type: str  # "national_id" | "passport"


class KycResult(BaseModel):
    user_id: str
    status: str
    submitted_at: str


@app.on_event("startup")
def ensure_schema():
    """Create the minimal table used by this demo, so `docker compose up` is enough to try it end to end."""
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS kyc_submissions (
                user_id TEXT PRIMARY KEY,
                full_name TEXT NOT NULL,
                id_document_type TEXT NOT NULL,
                status TEXT NOT NULL,
                submitted_at TIMESTAMPTZ NOT NULL
            );
            """
        )
    conn.close()


@app.get("/health")
def health():
    return {"status": "ok", "time": datetime.now(timezone.utc).isoformat()}


@app.post("/kyc/submit", response_model=KycResult)
def submit_kyc(payload: KycRequest):
    # simple in-memory rate limit via Redis: 5 submissions / user / hour
    key = f"kyc_rate:{payload.user_id}"
    attempts = redis_client.incr(key)
    if attempts == 1:
        redis_client.expire(key, 3600)
    if attempts > 5:
        raise HTTPException(status_code=429, detail="Too many KYC submissions — try again later")

    submitted_at = datetime.now(timezone.utc)
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO kyc_submissions (user_id, full_name, id_document_type, status, submitted_at)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (user_id) DO UPDATE
            SET full_name = EXCLUDED.full_name,
                id_document_type = EXCLUDED.id_document_type,
                status = EXCLUDED.status,
                submitted_at = EXCLUDED.submitted_at;
            """,
            (payload.user_id, payload.full_name, payload.id_document_type, "under_review", submitted_at),
        )
    conn.close()

    return KycResult(user_id=payload.user_id, status="under_review", submitted_at=submitted_at.isoformat())


@app.get("/kyc/{user_id}", response_model=KycResult)
def get_kyc_status(user_id: str):
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            "SELECT user_id, status, submitted_at FROM kyc_submissions WHERE user_id = %s;",
            (user_id,),
        )
        row = cur.fetchone()
    conn.close()

    if not row:
        raise HTTPException(status_code=404, detail="No KYC submission found for this user")

    return KycResult(user_id=row[0], status=row[1], submitted_at=row[2].isoformat())
