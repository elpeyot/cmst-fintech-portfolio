"""
CMST — Lending & Campaigns service (portfolio demo).

Handles campaign creation (fundraiser flow) and investment into a campaign
(investor flow — "Invest Directly" from the white paper). Each investment
is written to the DB and would, in production, also be published to the
Kinesis event stream for the analytics pipeline to pick up.
"""
import os
import uuid
from datetime import datetime, timezone

import psycopg2
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="CMST Lending & Campaigns Service", version="0.1.0")

DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "cmst")
DB_USER = os.getenv("DB_USER", "cmst_admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "cmst_local_dev_only")


def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD
    )


class CampaignRequest(BaseModel):
    fundraiser_id: str
    title: str
    target_usd: float
    term_months: int
    monthly_rate_pct: float


class InvestRequest(BaseModel):
    investor_id: str
    amount_usd: float


@app.on_event("startup")
def ensure_schema():
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS campaigns (
                campaign_id TEXT PRIMARY KEY,
                fundraiser_id TEXT NOT NULL,
                title TEXT NOT NULL,
                target_usd NUMERIC NOT NULL,
                raised_usd NUMERIC NOT NULL DEFAULT 0,
                term_months INT NOT NULL,
                monthly_rate_pct NUMERIC NOT NULL,
                status TEXT NOT NULL DEFAULT 'open',
                created_at TIMESTAMPTZ NOT NULL
            );
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS investments (
                investment_id TEXT PRIMARY KEY,
                campaign_id TEXT NOT NULL REFERENCES campaigns(campaign_id),
                investor_id TEXT NOT NULL,
                amount_usd NUMERIC NOT NULL,
                invested_at TIMESTAMPTZ NOT NULL
            );
            """
        )
    conn.close()


@app.get("/health")
def health():
    return {"status": "ok", "time": datetime.now(timezone.utc).isoformat()}


@app.post("/lending/campaigns")
def create_campaign(payload: CampaignRequest):
    campaign_id = str(uuid.uuid4())
    created_at = datetime.now(timezone.utc)

    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO campaigns (campaign_id, fundraiser_id, title, target_usd, term_months, monthly_rate_pct, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s);
            """,
            (campaign_id, payload.fundraiser_id, payload.title, payload.target_usd, payload.term_months, payload.monthly_rate_pct, created_at),
        )
    conn.close()

    return {"campaign_id": campaign_id, "status": "open", "created_at": created_at.isoformat()}


@app.get("/lending/campaigns")
def list_campaigns():
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            "SELECT campaign_id, title, target_usd, raised_usd, term_months, monthly_rate_pct, status FROM campaigns ORDER BY created_at DESC;"
        )
        rows = cur.fetchall()
    conn.close()

    return [
        {
            "campaign_id": r[0], "title": r[1], "target_usd": float(r[2]), "raised_usd": float(r[3]),
            "term_months": r[4], "monthly_rate_pct": float(r[5]), "status": r[6],
        }
        for r in rows
    ]


@app.post("/lending/campaigns/{campaign_id}/invest")
def invest(campaign_id: str, payload: InvestRequest):
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute("SELECT target_usd, raised_usd FROM campaigns WHERE campaign_id = %s;", (campaign_id,))
        row = cur.fetchone()
        if not row:
            conn.close()
            raise HTTPException(status_code=404, detail="Campaign not found")

        target_usd, raised_usd = float(row[0]), float(row[1])
        investment_id = str(uuid.uuid4())
        invested_at = datetime.now(timezone.utc)

        cur.execute(
            "INSERT INTO investments (investment_id, campaign_id, investor_id, amount_usd, invested_at) VALUES (%s,%s,%s,%s,%s);",
            (investment_id, campaign_id, payload.investor_id, payload.amount_usd, invested_at),
        )

        new_raised = raised_usd + payload.amount_usd
        new_status = "funded" if new_raised >= target_usd else "open"
        cur.execute(
            "UPDATE campaigns SET raised_usd = %s, status = %s WHERE campaign_id = %s;",
            (new_raised, new_status, campaign_id),
        )
    conn.close()

    return {
        "investment_id": investment_id,
        "campaign_id": campaign_id,
        "raised_usd": new_raised,
        "status": new_status,
    }
