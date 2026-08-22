# Kinesis Data Stream is used here instead of MSK/Kafka to keep the demo
# cheap and dependency-free. See docs/adr/0003-kinesis-over-msk.md.
resource "aws_kinesis_stream" "events" {
  name             = "${var.project}-events"
  shard_count      = var.shard_count
  retention_period = 48

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = { Name = "${var.project}-events" }
}
