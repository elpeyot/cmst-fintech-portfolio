#!/usr/bin/env bash
# Builds and pushes all five CMST service images to ECR, then deploys the
# full stack with Terraform. Intended for manual runs from your VM;
# .github/workflows/terraform-deploy.yml does the same via CI/OIDC.
set -euo pipefail
cd "$(dirname "$0")/.."

REGION="${AWS_REGION:-eu-west-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

SERVICES=(kyc-service circles-service lending-service arbitration-service payments-service)

echo "==> Logging in to ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

declare -A IMAGE_URIS

for svc in "${SERVICES[@]}"; do
  REPO_NAME="cmst-${svc}"
  ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}"
  IMAGE_URIS[$svc]="${ECR_URI}:latest"

  echo "==> [$svc] Ensuring ECR repo exists..."
  aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$REGION" >/dev/null 2>&1 \
    || aws ecr create-repository --repository-name "$REPO_NAME" --region "$REGION" >/dev/null

  echo "==> [$svc] Building and pushing image..."
  docker build -t "${ECR_URI}:latest" "services/${svc}"
  docker push "${ECR_URI}:latest"
done

echo "==> terraform init / plan / apply..."
cd infra
terraform init
terraform plan \
  -var="kyc_image_uri=${IMAGE_URIS[kyc-service]}" \
  -var="circles_image_uri=${IMAGE_URIS[circles-service]}" \
  -var="lending_image_uri=${IMAGE_URIS[lending-service]}" \
  -var="arbitration_image_uri=${IMAGE_URIS[arbitration-service]}" \
  -var="payments_image_uri=${IMAGE_URIS[payments-service]}" \
  -out=tfplan

read -r -p "Apply this plan? [y/N] " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  terraform apply tfplan
  echo ""
  echo "Done. Public base URL:"
  BASE="$(terraform output -raw alb_dns_name)"
  echo "  http://${BASE}"
  echo ""
  echo "Try each service:"
  for svc_path in kyc circles lending arbitration payments; do
    echo "  http://${BASE}/${svc_path}/..."
  done
else
  echo "Aborted — nothing was applied."
fi
