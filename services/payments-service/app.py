"""
CMST — Payments / PSP integration service (portfolio demo).

Mocks the payment-gateway role described in the white paper's
"How does money get in and out?" section: moving money between a user's
bank/mobile-money account and their CMST balance. In production this
would call a real PSP API (bank acquiring, mobile-money aggregator);
here it simulates settlement so the rest of the platform has a real
endpoint to integrate against.
"""
import os
import random
import uuid
from datetime import datetime, timezone

import psycopg2
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="CMST Payments Service", version="0.1.0")

DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "cmst")
DB_USER = os.getenv("DB_USER", "cmst_admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "cmst_local_dev_only")

VALID_METHODS = {"bank_transfer", "mobile_money", "card"}


def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD
    )


class PaymentRequest(BaseModel):
    user_id: str
    amount_usd: float
    method: str  # "bank_transfer" | "mobile_money" | "card"
    direction: str  # "cash_in" | "cash_out"


@app.on_event("startup")
def ensure_schema():
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS payments (
                payment_id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                amount_usd NUMERIC NOT NULL,
                method TEXT NOT NULL,
                direction TEXT NOT NULL,
                status TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL
            );
            """
        )
    conn.close()


@app.get("/health")
def health():
    return {"status": "ok", "time": datetime.now(timezone.utc).isoformat()}


@app.post("/payments")
def create_payment(payload: PaymentRequest):
    if payload.method not in VALID_METHODS:
        raise HTTPException(status_code=400, detail=f"method must be one of {sorted(VALID_METHODS)}")
    if payload.direction not in ("cash_in", "cash_out"):
        raise HTTPException(status_code=400, detail="direction must be 'cash_in' or 'cash_out'")

    # Simulated PSP settlement — in production this is a call to a real
    # acquiring bank / mobile-money aggregator API.
    status = "settled" if random.random() > 0.05 else "failed"

    payment_id = str(uuid.uuid4())
    created_at = datetime.now(timezone.utc)

    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO payments (payment_id, user_id, amount_usd, method, direction, status, created_at)
            VALUES (%s,%s,%s,%s,%s,%s,%s);
            """,
            (payment_id, payload.user_id, payload.amount_usd, payload.method, payload.direction, status, created_at),
        )
    conn.close()

    return {"payment_id": payment_id, "status": status, "created_at": created_at.isoformat()}


@app.get("/payments/{payment_id}")
def get_payment(payment_id: str):
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            "SELECT user_id, amount_usd, method, direction, status, created_at FROM payments WHERE payment_id = %s;",
            (payment_id,),
        )
        row = cur.fetchone()
    conn.close()

    if not row:
        raise HTTPException(status_code=404, detail="Payment not found")

    return {
        "payment_id": payment_id, "user_id": row[0], "amount_usd": float(row[1]), "method": row[2],
        "direction": row[3], "status": row[4], "created_at": row[5].isoformat(),
    }
