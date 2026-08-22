resource "aws_s3_bucket" "lake" {
  bucket = "${var.project}-data-lake-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${var.project}-data-lake" }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "lake" {
  bucket                  = aws_s3_bucket.lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "raw_prefix" {
  bucket = aws_s3_bucket.lake.id
  key    = "raw/.keep"
  content = ""
}

resource "aws_s3_object" "curated_prefix" {
  bucket  = aws_s3_bucket.lake.id
  key     = "curated/.keep"
  content = ""
}

resource "aws_glue_catalog_database" "this" {
  name = "${var.project}_analytics"
}
