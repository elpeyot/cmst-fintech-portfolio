variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "multi_az_rds" {
  description = "Enable Multi-AZ on RDS (off by default to keep the demo cheap)"
  type        = bool
  default     = false
}

variable "kyc_image_uri"         { type = string }
variable "circles_image_uri"     { type = string }
variable "lending_image_uri"     { type = string }
variable "arbitration_image_uri" { type = string }
variable "payments_image_uri"    { type = string }
