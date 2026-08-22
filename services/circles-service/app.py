"""
CMST — Circles service (portfolio demo).

Manages the ANRR trust circles (Area, Nation, Relative, Religion) that a
user allocates their lending/investing portfolio across, per the CMST
white paper's "Invest (loan) portfolio" model.
"""
import os
from datetime import datetime, timezone

import psycopg2
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="CMST Circles Service", version="0.1.0")

DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "cmst")
DB_USER = os.getenv("DB_USER", "cmst_admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "cmst_local_dev_only")

CIRCLE_RATES = {"area": 7.0, "nation": 6.0, "relative": 3.0, "religion": 2.0}


def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD
    )


class JoinCircleRequest(BaseModel):
    user_id: str
    circle_type: str  # "area" | "nation" | "relative" | "religion"


class CircleMembership(BaseModel):
    user_id: str
    circle_type: str
    monthly_rate_pct: float
    joined_at: str


@app.on_event("startup")
def ensure_schema():
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS circle_memberships (
                user_id TEXT NOT NULL,
                circle_type TEXT NOT NULL,
                monthly_rate_pct NUMERIC NOT NULL,
                joined_at TIMESTAMPTZ NOT NULL,
                PRIMARY KEY (user_id, circle_type)
            );
            """
        )
    conn.close()


@app.get("/health")
def health():
    return {"status": "ok", "time": datetime.now(timezone.utc).isoformat()}


@app.post("/circles/join", response_model=CircleMembership)
def join_circle(payload: JoinCircleRequest):
    circle_type = payload.circle_type.lower()
    if circle_type not in CIRCLE_RATES:
        raise HTTPException(status_code=400, detail=f"Unknown circle type. Must be one of {list(CIRCLE_RATES)}")

    joined_at = datetime.now(timezone.utc)
    rate = CIRCLE_RATES[circle_type]

    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO circle_memberships (user_id, circle_type, monthly_rate_pct, joined_at)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (user_id, circle_type) DO NOTHING;
            """,
            (payload.user_id, circle_type, rate, joined_at),
        )
    conn.close()

    return CircleMembership(
        user_id=payload.user_id, circle_type=circle_type, monthly_rate_pct=rate, joined_at=joined_at.isoformat()
    )


@app.get("/circles/{user_id}")
def get_user_circles(user_id: str):
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            "SELECT circle_type, monthly_rate_pct, joined_at FROM circle_memberships WHERE user_id = %s;",
            (user_id,),
        )
        rows = cur.fetchall()
    conn.close()

    return {
        "user_id": user_id,
        "circles": [
            {"circle_type": r[0], "monthly_rate_pct": float(r[1]), "joined_at": r[2].isoformat()} for r in rows
        ],
    }
