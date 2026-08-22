# ADR 0001: Terraform over CDK/Pulumi

**Status:** Accepted

**Context:** Needed an IaC tool for a multi-cloud-capable, recruiter-legible
portfolio piece.

**Decision:** Terraform (HCL), not AWS CDK or Pulumi.

**Rationale:**
- Terraform is the most commonly required IaC skill in fintech/DevOps job
  postings, ahead of CDK or Pulumi, and is not tied to one cloud provider.
- HCL is declarative and readable in a code review without needing to run
  it, which matters when a recruiter is skimming a GitHub repo rather than
  executing it.
- The module structure (network / security / rds / ecs / streaming /
  analytics) maps directly onto the architecture diagram, which is useful
  for talking through the design in an interview.

**Consequences:** Less flexibility than a general-purpose language (CDK/
Pulumi) for complex conditional logic — acceptable for a demo-scoped
project.
