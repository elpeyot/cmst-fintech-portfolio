#!/usr/bin/env bash
# Brings up the entire local stack — all 5 services + Postgres + Redis + Airflow —
# with zero AWS cost. Run this first before touching Terraform.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Starting app stack (postgres, redis, 5 services, adminer)..."
docker compose up -d --build

echo "==> Waiting for Postgres to be healthy..."
until docker compose exec -T postgres pg_isready -U cmst_admin -d cmst >/dev/null 2>&1; do
  sleep 2
done
echo "    Postgres is ready."

echo "==> Running dbt seed + run + test (local target, against the compose Postgres)..."

( cd analytics/dbt && dbt seed --target local && dbt run --target local && dbt test --target local )

echo "==> Starting Airflow (standalone mode)..."
docker compose -f analytics/airflow/docker-compose.airflow.yml up -d

cat << 'MSG'

Stack is up:
  kyc-service          -> http://localhost:8080/health
  circles-service       -> http://localhost:8083/health
  lending-service        -> http://localhost:8084/health
  arbitration-service    -> http://localhost:8085/health
  payments-service       -> http://localhost:8086/health
  adminer (DB)           -> http://localhost:8081  (server: postgres, user: cmst_admin, db: cmst)
  airflow                -> http://localhost:8082  (creds printed on first boot in `docker compose -f analytics/airflow/docker-compose.airflow.yml logs airflow`)

Try the flow end to end:

  # 1. KYC
  curl -X POST localhost:8080/kyc/submit -H 'Content-Type: application/json' \
    -d '{"user_id":"u_ama","full_name":"Ama Owusu","id_document_type":"national_id"}'

  # 2. Join a trust circle
  curl -X POST localhost:8083/circles/join -H 'Content-Type: application/json' \
    -d '{"user_id":"u_ama","circle_type":"area"}'

  # 3. Fundraiser opens a campaign
  curl -X POST localhost:8084/lending/campaigns -H 'Content-Type: application/json' \
    -d '{"fundraiser_id":"u_johnatan","title":"Textile Import","target_usd":10000,"term_months":6,"monthly_rate_pct":5}'

  # 4. Investor funds it (use the campaign_id returned above)
  curl -X POST localhost:8084/lending/campaigns/<campaign_id>/invest -H 'Content-Type: application/json' \
    -d '{"investor_id":"u_ama","amount_usd":540}'

  # 5. Cash-in via mobile money
  curl -X POST localhost:8086/payments -H 'Content-Type: application/json' \
    -d '{"user_id":"u_ama","amount_usd":540,"method":"mobile_money","direction":"cash_in"}'

  # 6. Open an arbitration case on an overdue loan
  curl -X POST localhost:8085/arbitration/cases -H 'Content-Type: application/json' \
    -d '{"loan_id":"105","debtor_id":"u_nash","reason":"3 days overdue"}'

Tear down with: docker compose down -v && docker compose -f analytics/airflow/docker-compose.airflow.yml down -v
MSG
