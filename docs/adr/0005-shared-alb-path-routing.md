# ADR 0005: One shared ALB with path-based routing, not one ALB per service

**Status:** Accepted

**Context:** The platform has five services (kyc, circles, lending,
arbitration, payments), each needing a public entry point behind the
ECS Fargate tasks.

**Decision:** A single Application Load Balancer routes to all five
services by path prefix (`/kyc/*`, `/circles/*`, `/lending/*`,
`/arbitration/*`, `/payments/*`), using one listener with five
`aws_lb_listener_rule` resources and five target groups — not five
separate ALBs.

**Rationale:**
- Each ALB has an hourly + LCU cost; five ALBs for a five-service demo
  is roughly a 5x avoidable cost for no architectural benefit at this
  scale.
- A single public entry point is also simpler to put a WAF/CloudFront/
  TLS certificate in front of once, rather than five times.
- The `ecs_service` Terraform module was written to be entirely
  ALB-agnostic (it only needs a `listener_arn` and a `path_prefix`),
  so adding a sixth service later is a five-line module block, not a
  new load balancer.

**Consequences:** All services currently share one Postgres instance/
database (see `docker-compose.yml` and `infra/modules/rds`) for the
same reason — this is fine for a portfolio-scale demo, but a real
production system would likely split the database per service (or at
least per schema) once traffic and team ownership justify it.
