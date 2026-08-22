#!/usr/bin/env bash
# Checks the tools this repo needs and reports what's missing.
# Written to be safe to run on a VM that already has most DevOps tooling
# preinstalled — it won't reinstall anything that's already present.
set -euo pipefail

need() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "  [ok] $1 -> $($1 --version 2>&1 | head -n1)"
  else
    echo "  [MISSING] $1"
    MISSING=1
  fi
}

echo "Checking required tools..."
MISSING=0
need git
need docker
need terraform
need aws
need python3
need pip3

if [ "${MISSING:-0}" -eq 1 ]; then
  echo ""
  echo "Some tools are missing. On Ubuntu/Debian you can install the common ones with:"
  echo "  sudo apt-get update && sudo apt-get install -y git python3 python3-pip"
  echo "  # Docker: https://docs.docker.com/engine/install/ubuntu/"
  echo "  # Terraform: https://developer.hashicorp.com/terraform/install"
  echo "  # AWS CLI:  https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  exit 1
fi

echo ""
echo "All required tools are present."
echo ""
echo "Next: confirm AWS credentials are configured:"
echo "  aws sts get-caller-identity"
echo ""
echo "If not yet configured, run: aws configure"
echo "(or, preferably for CI, use an IAM role via 'aws configure sso' / OIDC — see docs/adr/0004-aws-auth.md)"
