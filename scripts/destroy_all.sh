#!/usr/bin/env bash
# Tears down local containers AND AWS infra. Use to avoid leaving
# billable AWS resources running after a portfolio review/demo.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Stopping local containers..."
docker compose down -v || true
docker compose -f analytics/airflow/docker-compose.airflow.yml down -v || true

echo "==> Destroying AWS infrastructure..."
cd infra
terraform destroy
