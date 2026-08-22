.PHONY: check local-up local-down dbt-run dbt-test tf-init tf-plan tf-apply destroy

check:        ## verify required tools are installed
	./scripts/bootstrap_vm.sh

local-up:     ## start the full local stack (docker compose + dbt + airflow)
	./scripts/local_up.sh

local-down:   ## stop local containers
	docker compose down -v
	docker compose -f analytics/airflow/docker-compose.airflow.yml down -v

dbt-run:      ## run dbt models against the local compose Postgres
	cd analytics/dbt && dbt run --target local

dbt-test:     ## run dbt data tests
	cd analytics/dbt && dbt test --target local

tf-init:
	cd infra && terraform init

tf-plan:      ## prefer ./scripts/aws_deploy.sh — it builds/pushes all 5 images and passes their URIs automatically
	cd infra && terraform plan

tf-apply:     ## deploy to AWS (prefer ./scripts/aws_deploy.sh for the full build+push+deploy flow)
	cd infra && terraform apply

destroy:      ## tear down local containers AND AWS infra
	./scripts/destroy_all.sh
