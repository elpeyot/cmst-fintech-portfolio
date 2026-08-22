# ---------------------------------------------------------------
# Security groups are chained SG -> SG, not CIDR-based.
# See docs/adr/0002-sg-chaining-over-cidr.md for the rationale.
# ---------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.project}-sg-alb"
  description = "Public ALB — internet on 443/80 only"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet (redirected to HTTPS at listener level)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg-alb" }
}

resource "aws_security_group" "app" {
  name        = "${var.project}-sg-app"
  description = "ECS services — only reachable from the ALB"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg-app" }
}

resource "aws_security_group_rule" "alb_to_app" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
  description               = "ALB -> app container port"
}

resource "aws_security_group" "data" {
  name        = "${var.project}-sg-data"
  description = "RDS / Redis / Kinesis consumers — only reachable from the app tier"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.project}-sg-data" }
}

resource "aws_security_group_rule" "app_to_postgres" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.data.id
  source_security_group_id = aws_security_group.app.id
  description               = "app -> RDS PostgreSQL"
}

resource "aws_security_group_rule" "app_to_redis" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.data.id
  source_security_group_id = aws_security_group.app.id
  description               = "app -> ElastiCache Redis"
}

resource "aws_security_group" "analytics" {
  name        = "${var.project}-sg-analytics"
  description = "ETL / analytics workloads reading from the data tier"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg-analytics" }
}

resource "aws_security_group_rule" "analytics_to_postgres" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.data.id
  source_security_group_id = aws_security_group.analytics.id
  description               = "ETL -> RDS PostgreSQL (read replica in production)"
}
