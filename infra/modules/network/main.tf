data "aws_region" "current" {}

locals {
  az_suffixes = var.azs
  full_azs    = [for s in var.azs : "${data.aws_region.current.name}${s}"]

  # /24 subnets carved out of the /16 VPC CIDR: 3 tiers x N AZs
  public_cidrs  = [for i, az in local.full_azs : cidrsubnet(var.vpc_cidr, 8, i)]
  app_cidrs     = [for i, az in local.full_azs : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  data_cidrs    = [for i, az in local.full_azs : cidrsubnet(var.vpc_cidr, 8, i + 20)]

  tags = {
    Project     = var.project
    ManagedBy   = "terraform"
    Environment = "portfolio-demo"
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.project}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.project}-igw" })
}

# ---------- Public subnets (ALB, NAT) ----------
resource "aws_subnet" "public" {
  count                   = length(local.full_azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.full_azs[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "${var.project}-public-${local.az_suffixes[count.index]}", Tier = "public" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.project}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id              = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------- NAT Gateway (single, for cost — flip single_nat_gateway=false for per-AZ HA) ----------
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(local.full_azs)
  domain = "vpc"
  tags   = merge(local.tags, { Name = "${var.project}-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count         = var.single_nat_gateway ? 1 : length(local.full_azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(local.tags, { Name = "${var.project}-nat-${count.index}" })
  depends_on    = [aws_internet_gateway.this]
}

# ---------- Private app subnets (ECS services) ----------
resource "aws_subnet" "app" {
  count             = length(local.full_azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.app_cidrs[count.index]
  availability_zone = local.full_azs[count.index]
  tags              = merge(local.tags, { Name = "${var.project}-app-${local.az_suffixes[count.index]}", Tier = "app" })
}

resource "aws_route_table" "app" {
  count  = length(local.full_azs)
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.project}-app-rt-${local.az_suffixes[count.index]}" })
}

resource "aws_route" "app_nat" {
  count                  = length(local.full_azs)
  route_table_id         = aws_route_table.app[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "app" {
  count          = length(aws_subnet.app)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

# ---------- Private data subnets (RDS, Redis, Kinesis consumers) — no NAT route, fully isolated ----------
resource "aws_subnet" "data" {
  count             = length(local.full_azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.data_cidrs[count.index]
  availability_zone = local.full_azs[count.index]
  tags              = merge(local.tags, { Name = "${var.project}-data-${local.az_suffixes[count.index]}", Tier = "data" })
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.project}-data-rt" })
}

resource "aws_route_table_association" "data" {
  count          = length(aws_subnet.data)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

# ---------- VPC endpoints so S3 / Secrets Manager / KMS traffic never leaves AWS network ----------
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(aws_route_table.app[*].id, [aws_route_table.data.id])
  tags              = merge(local.tags, { Name = "${var.project}-vpce-s3" })
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.app[*].id
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce.id]
  tags                = merge(local.tags, { Name = "${var.project}-vpce-secretsmanager" })
}

resource "aws_security_group" "vpce" {
  name        = "${var.project}-vpce-sg"
  description = "Allow app tier to reach interface VPC endpoints on 443"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project}-vpce-sg" })
}
