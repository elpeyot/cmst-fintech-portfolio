# ADR 0002: Security-group chaining over CIDR-based rules

**Status:** Accepted

**Context:** Any inter-tier traffic inside the VPC (ALB → app, app → DB,
app → cache, ETL → DB) needs an authorisation rule.

**Decision:** Every internal security-group rule references a
`source_security_group_id`, never a CIDR block inside the VPC.

**Rationale:**
- CIDR-based rules authorise *any resource in that subnet*, including ones
  added later that shouldn't have access — a common source of
  over-permissioned fintech infrastructure.
- SG-chaining authorises by resource identity: only ECS tasks actually
  wearing `sg-app` can reach the database, regardless of which subnet they
  land in.
- This is a low-cost way to demonstrate least-privilege network design in
  a portfolio review.

**Consequences:** Slightly more Terraform resources (separate
`aws_security_group_rule` blocks) than one big CIDR-based ingress list —
worth it for the auditability.
