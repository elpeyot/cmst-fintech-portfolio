# ADR 0004: OIDC over long-lived IAM keys for CI

**Status:** Accepted

**Context:** GitHub Actions needs AWS credentials to run `terraform plan`
/ `apply`.

**Decision:** Use GitHub's OIDC provider with an assumable IAM role
(`AWS_ROLE_ARN` secret), not static `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
secrets.

**Rationale:**
- Long-lived access keys stored as repo secrets are a well-known leak
  vector; OIDC issues short-lived, per-run credentials instead.
- This is close to table-stakes practice in regulated environments and is
  worth calling out explicitly to a fintech recruiter.

**Consequences:** Requires a one-time setup of an IAM OIDC identity
provider and a trust policy scoped to this repo — documented in
`README.md` under "AWS deployment".
