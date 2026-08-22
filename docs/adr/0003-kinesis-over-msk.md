# ADR 0003: Kinesis Data Streams over MSK (Kafka) for the demo

**Status:** Accepted

**Context:** The architecture needs an event bus between the app tier
and the analytics pipeline (loan created, repayment received, arbitration
case opened).

**Decision:** Use Kinesis Data Streams for the portfolio deployment, not
Amazon MSK.

**Rationale:**
- MSK has a non-trivial minimum cost (broker-hours) even at the smallest
  size, unsuitable for a "spin up, demo, tear down" portfolio project.
- Kinesis has per-shard pricing with no cluster to manage and a single
  Terraform resource, keeping the module a five-minute read.
- The producer/consumer pattern taught here (services write events,
  ETL reads them) transfers directly to Kafka/MSK if a real production
  system later needs Kafka-specific features (consumer groups, long
  retention, exactly-once semantics).

**Consequences:** Kinesis has different scaling/partitioning semantics
than Kafka — call this out explicitly if discussing the project with an
interviewer who asks "why not Kafka?".
