# CMST — Fintech Cloud Platform (DevOps + Analytics Portfolio)

A working (not just diagrammed) reference implementation of the cloud
architecture behind **CMST / Cowrie** — a crowd-lending and crowd-investing
social network for extended-family economies, built around trust circles
(Area / Nation / Relative / Religion) and a multi-level loan-guarantee
system.

This repo demonstrates two skill sets against one coherent, non-generic
fintech domain, rather than two unrelated toy projects:

- **DevOps / Cloud**: VPC design, security-group least privilege, ECS
  Fargate, a shared ALB with path-based routing, Terraform modules,
  CI/CD with GitHub Actions, OIDC auth, observability.
- **Analytics engineering**: an ELT pipeline (Kinesis → S3 → dbt →
  warehouse) with tested, documented models and a headline metric —
  **loan default rate by trust-circle type** — that speaks directly to
  whether the underlying business model (community-backed guarantees)
  actually works.

All five services from the architecture diagram are implemented, not
stubbed: **KYC, Circles, Lending & Campaigns, Guaranty & Arbitration,
Payments**. Everything below runs on a plain Linux VM with Docker,
Terraform, the AWS CLI and Git installed — no proprietary tooling
required.

---

## Architecture

See [`docs/architecture.mermaid`](docs/architecture.mermaid) for the full
diagram. Summary:

```
Users → Route53 → CloudFront + WAF → shared ALB (path-based routing)
                                        │
        ┌───────────┬───────────┬───────────┬───────────────┐
     /kyc/*      /circles/*   /lending/*  /arbitration/*  /payments/*
        │           │           │           │               │
       KYC       Circles     Lending    Arbitration      Payments
        │           │           │           │               │
        └─────── RDS Postgres (private data subnet) ─────────┘
                    │
              Kinesis event stream
                    │
        Airflow → S3 data lake → dbt → Redshift/Postgres → BI dashboard
```

All five services sit behind **one** ALB (see
[`docs/adr/0005-shared-alb-path-routing.md`](docs/adr/0005-shared-alb-path-routing.md)
for why), routed by path prefix, each with its own ECS task definition
and target group.

Network/security design: [`docs/sg-table.md`](docs/sg-table.md).
Design rationale for the non-obvious choices: [`docs/adr/`](docs/adr/).

---

## The five services

| Service | Path prefix | Local port | What it does |
|---|---|---|---|
| `kyc-service` | `/kyc` | 8080 | Identity verification, rate-limited via Redis |
| `circles-service` | `/circles` | 8083 | ANRR trust-circle membership (Area/Nation/Relative/Religion), each with its own fixed monthly rate |
| `lending-service` | `/lending` | 8084 | Campaign creation (fundraiser) and investment (investor) |
| `arbitration-service` | `/arbitration` | 8085 | Community dispute resolution with quorum-based voting, per the white paper's guaranty system |
| `payments-service` | `/payments` | 8086 | Mock PSP integration — bank transfer / mobile money / card, cash-in and cash-out |

Each is a small FastAPI service with its own `Dockerfile`,
`requirements.txt` and smoke test, sharing one Postgres instance (own
tables) for the demo — see ADR 0005 for why, and what a production split
would look like.

---

## Repository structure

```
infra/                        Terraform — VPC, security groups, RDS, shared
                               ALB, ECS cluster, one ecs_service module per
                               service, Kinesis, S3 data lake + Glue catalog
services/
  kyc-service/                 5 FastAPI microservices, one per row in the
  circles-service/              table above — each independently buildable,
  lending-service/              testable and deployable
  arbitration-service/
  payments-service/
analytics/dbt/                dbt project: seeds, staging models, marts,
                               data tests (default-rate-by-circle metric)
analytics/airflow/            Airflow DAG orchestrating the ELT pipeline
.github/workflows/             CI (tests for all 5 services + terraform
                               validate) and a gated Terraform plan/apply
docs/                          Architecture diagram, ADRs, SG table
scripts/                       bootstrap_vm.sh, local_up.sh, aws_deploy.sh,
                                destroy_all.sh
Makefile                       Shortcuts for everything below
```

---

## Quickstart — local only, zero AWS cost

Run on any Linux VM with Docker, Python 3.11+ and Git.

```bash
git clone <this-repo-url>
cd cmst-fintech-portfolio

./scripts/bootstrap_vm.sh      # confirms git/docker/terraform/aws-cli/python are present
pip install --break-system-packages dbt-postgres

make local-up                  # docker compose up (all 5 services) + dbt seed/run/test + airflow
```

Then walk the full flow end to end — KYC → join a circle → open a
campaign → invest → cash-in a payment → open an arbitration case — using
the `curl` examples printed by `local_up.sh` (also in
[`scripts/local_up.sh`](scripts/local_up.sh)).

Inspect the analytics output directly:

```bash
cd analytics/dbt
dbt show --select circle_default_rates --target local
```

Tear down: `make local-down`

---

## Deploying to AWS

Requires an AWS account and the AWS CLI configured (`aws configure` or SSO).

```bash
export AWS_REGION=eu-west-1
./scripts/aws_deploy.sh
```

This builds and pushes all five images to ECR, then runs
`terraform init / plan`, asking for confirmation before `apply`. On
success it prints the shared ALB's DNS name and the path for each
service (e.g. `http://<alb>/kyc/health`).

**Before running in CI** (`.github/workflows/terraform-deploy.yml`), set up
OIDC auth per [`docs/adr/0004-aws-auth.md`](docs/adr/0004-aws-auth.md) and add:
- Repo secret `AWS_ROLE_ARN`
- Repo variables `KYC_IMAGE_URI`, `CIRCLES_IMAGE_URI`, `LENDING_IMAGE_URI`,
  `ARBITRATION_IMAGE_URI`, `PAYMENTS_IMAGE_URI`
- A `production` GitHub Environment with a required reviewer, so
  `terraform apply` on `main` needs a human approval click — the same
  control a real fintech change-management process would require.

**Cost note:** this deploys one NAT Gateway, one small RDS instance, five
small Fargate tasks, one shared ALB and one Kinesis shard — inexpensive,
but not free. Run `make destroy` (or `./scripts/destroy_all.sh`) when
you're done reviewing it so nothing keeps billing.

---

## What to point a recruiter at, specifically

1. `docs/architecture.mermaid` — the system in one view
2. `infra/modules/security/main.tf` + `docs/sg-table.md` — least-privilege
   network design
3. `infra/modules/ecs_service/` — the reusable per-service module that all
   five services share, wired onto one ALB via path-based routing
4. `analytics/dbt/models/marts/circle_default_rates.sql` — a metric with
   actual business meaning, not a generic "row count" demo model
5. `.github/workflows/terraform-deploy.yml` — OIDC auth + a manual
   approval gate before infrastructure changes hit `main`
6. `docs/adr/` — five ADRs explaining engineering judgement, not just
   tool usage (Terraform vs. CDK, SG-chaining, Kinesis vs. MSK, OIDC vs.
   static keys, shared ALB vs. one-per-service)

---

## Known simplifications (worth being upfront about in an interview)

- All five services share one Postgres instance rather than a database
  per service — deliberate, see ADR 0005.
- Airflow runs in single-container "standalone" mode locally, not the
  multi-container production topology — fine for demoing the DAG, not
  how you'd run it for real.
- Kinesis, not MSK/Kafka — see ADR 0003 for the cost/complexity
  trade-off, and what would change if a real deployment needed it.
- No TLS/ACM certificate on the ALB listener, to keep the demo
  certificate-free — noted inline in `infra/modules/alb/main.tf`.
