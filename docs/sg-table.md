# Security group design

Security groups are chained SG → SG rather than CIDR-based, so traffic is
authorised by *identity of the source resource*, not by IP range. This is
the first thing a fintech-savvy reviewer checks in an infra repo.

| Security group   | Direction | Port(s)          | Allowed source          | Purpose                                  |
|-------------------|-----------|-------------------|--------------------------|-------------------------------------------|
| `sg-alb`          | ingress   | 443, 80           | `0.0.0.0/0`              | Public entry point only                   |
| `sg-app`          | ingress   | 8080              | `sg-alb`                 | ECS services reachable only from the ALB  |
| `sg-data`         | ingress   | 5432 (Postgres)   | `sg-app`                 | DB reachable only from app tier           |
| `sg-data`         | ingress   | 6379 (Redis)      | `sg-app`                 | Cache reachable only from app tier        |
| `sg-analytics`    | ingress   | —                 | —                        | ETL workloads' own identity               |
| `sg-data`         | ingress   | 5432 (Postgres)   | `sg-analytics`           | ETL reads from DB (read replica in prod)  |
| `sg-vpce`         | ingress   | 443               | VPC CIDR                 | App tier reaching interface VPC endpoints |

No security group in this design allows an inbound CIDR range from within
the VPC — every internal rule points at a `source_security_group_id`.
