"""
CMST — Guaranty & Arbitration service (portfolio demo).

Implements the white paper's core fraud-prevention mechanism: a community
arbitration board that judges disputed/overdue loans. Guarantors and
broader backers vote; once a quorum is reached the case resolves to
"uphold_claim" or "grant_extension".
"""
import os
import uuid
from datetime import datetime, timezone

import psycopg2
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="CMST Guaranty & Arbitration Service", version="0.1.0")

DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "cmst")
DB_USER = os.getenv("DB_USER", "cmst_admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "cmst_local_dev_only")

QUORUM_VOTES = 3


def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD
    )


class OpenCaseRequest(BaseModel):
    loan_id: str
    debtor_id: str
    reason: str


class VoteRequest(BaseModel):
    voter_id: str
    verdict: str  # "uphold_claim" | "grant_extension"


@app.on_event("startup")
def ensure_schema():
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS arbitration_cases (
                case_id TEXT PRIMARY KEY,
                loan_id TEXT NOT NULL,
                debtor_id TEXT NOT NULL,
                reason TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'under_review',
                resolution TEXT,
                opened_at TIMESTAMPTZ NOT NULL,
                resolved_at TIMESTAMPTZ
            );
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS arbitration_votes (
                vote_id TEXT PRIMARY KEY,
                case_id TEXT NOT NULL REFERENCES arbitration_cases(case_id),
                voter_id TEXT NOT NULL,
                verdict TEXT NOT NULL,
                voted_at TIMESTAMPTZ NOT NULL,
                UNIQUE (case_id, voter_id)
            );
            """
        )
    conn.close()


@app.get("/health")
def health():
    return {"status": "ok", "time": datetime.now(timezone.utc).isoformat()}


@app.post("/arbitration/cases")
def open_case(payload: OpenCaseRequest):
    case_id = str(uuid.uuid4())
    opened_at = datetime.now(timezone.utc)

    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO arbitration_cases (case_id, loan_id, debtor_id, reason, opened_at) VALUES (%s,%s,%s,%s,%s);",
            (case_id, payload.loan_id, payload.debtor_id, payload.reason, opened_at),
        )
    conn.close()

    return {"case_id": case_id, "status": "under_review", "opened_at": opened_at.isoformat()}


@app.post("/arbitration/cases/{case_id}/vote")
def vote(case_id: str, payload: VoteRequest):
    if payload.verdict not in ("uphold_claim", "grant_extension"):
        raise HTTPException(status_code=400, detail="verdict must be 'uphold_claim' or 'grant_extension'")

    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute("SELECT status FROM arbitration_cases WHERE case_id = %s;", (case_id,))
        row = cur.fetchone()
        if not row:
            conn.close()
            raise HTTPException(status_code=404, detail="Case not found")
        if row[0] != "under_review":
            conn.close()
            raise HTTPException(status_code=409, detail=f"Case is already {row[0]}")

        vote_id = str(uuid.uuid4())
        voted_at = datetime.now(timezone.utc)
        cur.execute(
            "INSERT INTO arbitration_votes (vote_id, case_id, voter_id, verdict, voted_at) VALUES (%s,%s,%s,%s,%s) "
            "ON CONFLICT (case_id, voter_id) DO UPDATE SET verdict = EXCLUDED.verdict, voted_at = EXCLUDED.voted_at;",
            (vote_id, case_id, payload.voter_id, payload.verdict, voted_at),
        )

        cur.execute("SELECT verdict, COUNT(*) FROM arbitration_votes WHERE case_id = %s GROUP BY verdict;", (case_id,))
        tally = dict(cur.fetchall())
        total_votes = sum(tally.values())

        resolution = None
        if total_votes >= QUORUM_VOTES:
            resolution = max(tally, key=tally.get)
            cur.execute(
                "UPDATE arbitration_cases SET status = 'resolved', resolution = %s, resolved_at = %s WHERE case_id = %s;",
                (resolution, datetime.now(timezone.utc), case_id),
            )
    conn.close()

    return {"case_id": case_id, "tally": tally, "resolution": resolution, "status": "resolved" if resolution else "under_review"}


@app.get("/arbitration/cases/{case_id}")
def get_case(case_id: str):
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            "SELECT loan_id, debtor_id, reason, status, resolution, opened_at FROM arbitration_cases WHERE case_id = %s;",
            (case_id,),
        )
        row = cur.fetchone()
    conn.close()

    if not row:
        raise HTTPException(status_code=404, detail="Case not found")

    return {
        "case_id": case_id, "loan_id": row[0], "debtor_id": row[1], "reason": row[2],
        "status": row[3], "resolution": row[4], "opened_at": row[5].isoformat(),
    }
