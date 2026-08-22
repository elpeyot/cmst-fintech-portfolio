# Remote state — uncomment and fill in after creating your own state bucket
# and lock table (see scripts/aws_deploy.sh, which creates them for you if
# they don't exist yet).
#
# terraform {
#   backend "s3" {
#     bucket         = "cmst-portfolio-tfstate-<your-account-id>"
#     key            = "cmst/terraform.tfstate"
#     region         = "eu-west-1"
#     dynamodb_table = "cmst-portfolio-tf-locks"
#     encrypt        = true
#   }
# }
