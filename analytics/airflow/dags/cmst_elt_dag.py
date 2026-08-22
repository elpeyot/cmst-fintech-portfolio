"""
CMST ELT DAG (portfolio demo).

extract_events -> load_to_postgres -> dbt_run -> dbt_test

In production, `extract_events` would pull from the Kinesis stream
(see infra/modules/streaming) instead of generating mock rows, and
`load_to_postgres` would land raw events in S3 first (data lake) before
an incremental load into Postgres/Redshift. Kept as a direct DB write
here to keep the local demo dependency-free.
"""
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

default_args = {
    "owner": "cmst-data-eng",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}


def extract_events(**_):
    # Placeholder for a real Kinesis/S3 read — returns a small mock batch.
    return [
        {"loan_id": 106, "user_id": "u_benjamin", "circle_id": 1, "amount_usd": 1200, "status": "active"},
    ]


def load_to_postgres(**context):
    import psycopg2
    import os

    rows = context["ti"].xcom_pull(task_ids="extract_events")
    conn = psycopg2.connect(
        host=os.getenv("CMST_DB_HOST", "localhost"),
        port=os.getenv("CMST_DB_PORT", "5432"),
        dbname=os.getenv("CMST_DB_NAME", "cmst"),
        user=os.getenv("CMST_DB_USER", "cmst_admin"),
        password=os.getenv("CMST_DB_PASSWORD", "cmst_local_dev_only"),
    )
    with conn, conn.cursor() as cur:
        for row in rows:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS raw_loan_events (
                    loan_id INT, user_id TEXT, circle_id INT, amount_usd NUMERIC, status TEXT
                );
                """
            )
            cur.execute(
                "INSERT INTO raw_loan_events (loan_id, user_id, circle_id, amount_usd, status) VALUES (%s,%s,%s,%s,%s)",
                (row["loan_id"], row["user_id"], row["circle_id"], row["amount_usd"], row["status"]),
            )
    conn.close()


with DAG(
    dag_id="cmst_elt",
    description="Extract loan/repayment events, load to Postgres, transform with dbt",
    default_args=default_args,
    schedule="@hourly",
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["cmst", "analytics"],
) as dag:

    extract = PythonOperator(task_id="extract_events", python_callable=extract_events)

    load = PythonOperator(task_id="load_to_postgres", python_callable=load_to_postgres)

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=(
            "cd /opt/airflow/analytics/dbt && "
            "dbt run --profiles-dir . --target local"
        ),
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=(
            "cd /opt/airflow/analytics/dbt && "
            "dbt test --profiles-dir . --target local"
        ),
    )

    extract >> load >> dbt_run >> dbt_test
