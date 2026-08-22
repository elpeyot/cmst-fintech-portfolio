variable "project" {
  description = "Project name, used as a prefix for tagging and naming resources"
  type        = string
  default     = "cmst"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "Availability zones to deploy into"
  type        = list(string)
  default     = ["a", "b"]
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway for all AZs (cheaper, non-HA — fine for a portfolio/demo)"
  type        = bool
  default     = true
}
