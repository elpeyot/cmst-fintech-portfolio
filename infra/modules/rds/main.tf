resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-db-subnets"
  subnet_ids = var.subnet_ids
  tags       = { Name = "${var.project}-db-subnets" }
}

resource "random_password" "master" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.project}/rds/master-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
  })
}

resource "aws_kms_key" "rds" {
  description         = "${var.project} RDS encryption key"
  enable_key_rotation = true
}

resource "aws_db_instance" "this" {
  identifier              = "${var.project}-postgres"
  engine                  = "postgres"
  engine_version          = "16"
  instance_class          = var.instance_class
  allocated_storage       = 20
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.rds.arn
  db_name                 = var.db_name
  username                = var.master_username
  password                = random_password.master.result
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [var.sg_id]
  multi_az                = var.multi_az
  publicly_accessible     = false
  backup_retention_period = 7
  skip_final_snapshot     = true # demo only — set false + provide a snapshot identifier for production
  deletion_protection     = false # demo only — enable for production

  tags = { Name = "${var.project}-postgres" }
}
