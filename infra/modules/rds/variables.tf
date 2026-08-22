variable "project"       { type = string  default = "cmst" }
variable "subnet_ids"    { type = list(string) }
variable "sg_id"         { type = string }
variable "instance_class"{ type = string  default = "db.t4g.micro" }
variable "multi_az"      { type = bool    default = false }
variable "db_name"       { type = string  default = "cmst" }
variable "master_username" { type = string default = "cmst_admin" }
