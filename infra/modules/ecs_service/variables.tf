variable "project"        { type = string default = "cmst" }
variable "vpc_id"         { type = string }
variable "app_subnet_ids" { type = list(string) }
variable "app_sg_id"      { type = string }
variable "cluster_id"     { type = string }
variable "listener_arn"   { type = string }

variable "service_name"   { type = string  description = "e.g. kyc-service" }
variable "path_prefix"    { type = string  description = "ALB routing prefix, e.g. kyc -> matches /kyc/*" }
variable "listener_priority" { type = number  description = "Must be unique per service on the shared listener" }

variable "image_uri"      { type = string }
variable "container_port" { type = number default = 8080 }
variable "cpu"             { type = number default = 256 }
variable "memory"          { type = number default = 512 }
variable "desired_count"   { type = number default = 1 }

variable "environment" {
  description = "Extra environment variables for the container (e.g. DB_HOST)"
  type        = map(string)
  default     = {}
}
