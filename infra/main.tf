module "network" {
  source = "./modules/network"
}

module "security" {
  source   = "./modules/security"
  vpc_id   = module.network.vpc_id
  vpc_cidr = module.network.vpc_cidr
}

module "rds" {
  source     = "./modules/rds"
  subnet_ids = module.network.data_subnet_ids
  sg_id      = module.security.data_sg_id
  multi_az   = var.multi_az_rds
}

module "streaming" {
  source = "./modules/streaming"
}

module "analytics" {
  source = "./modules/analytics"
}

module "alb" {
  source            = "./modules/alb"
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
}

module "ecs_cluster" {
  source = "./modules/ecs_cluster"
}

# ---------------------------------------------------------------
# All five CMST services share one ALB (path-based routing) and one
# ECS cluster. Each gets its own task definition, target group and
# listener rule. Priorities must stay unique across all five.
# ---------------------------------------------------------------

locals {
  common_env = {
    DB_HOST    = module.rds.endpoint
    DB_NAME    = "cmst"
    REDIS_HOST = "" # populated once an ElastiCache module is added; services fall back to no-op caching without it
  }
}

module "kyc_service" {
  source            = "./modules/ecs_service"
  vpc_id            = module.network.vpc_id
  app_subnet_ids    = module.network.app_subnet_ids
  app_sg_id         = module.security.app_sg_id
  cluster_id        = module.ecs_cluster.cluster_id
  listener_arn      = module.alb.listener_arn
  service_name      = "kyc-service"
  path_prefix       = "kyc"
  listener_priority = 10
  image_uri         = var.kyc_image_uri
  environment       = local.common_env
}

module "circles_service" {
  source            = "./modules/ecs_service"
  vpc_id            = module.network.vpc_id
  app_subnet_ids    = module.network.app_subnet_ids
  app_sg_id         = module.security.app_sg_id
  cluster_id        = module.ecs_cluster.cluster_id
  listener_arn      = module.alb.listener_arn
  service_name      = "circles-service"
  path_prefix       = "circles"
  listener_priority = 20
  image_uri         = var.circles_image_uri
  environment       = local.common_env
}

module "lending_service" {
  source            = "./modules/ecs_service"
  vpc_id            = module.network.vpc_id
  app_subnet_ids    = module.network.app_subnet_ids
  app_sg_id         = module.security.app_sg_id
  cluster_id        = module.ecs_cluster.cluster_id
  listener_arn      = module.alb.listener_arn
  service_name      = "lending-service"
  path_prefix       = "lending"
  listener_priority = 30
  image_uri         = var.lending_image_uri
  environment       = local.common_env
}

module "arbitration_service" {
  source            = "./modules/ecs_service"
  vpc_id            = module.network.vpc_id
  app_subnet_ids    = module.network.app_subnet_ids
  app_sg_id         = module.security.app_sg_id
  cluster_id        = module.ecs_cluster.cluster_id
  listener_arn      = module.alb.listener_arn
  service_name      = "arbitration-service"
  path_prefix       = "arbitration"
  listener_priority = 40
  image_uri         = var.arbitration_image_uri
  environment       = local.common_env
}

module "payments_service" {
  source            = "./modules/ecs_service"
  vpc_id            = module.network.vpc_id
  app_subnet_ids    = module.network.app_subnet_ids
  app_sg_id         = module.security.app_sg_id
  cluster_id        = module.ecs_cluster.cluster_id
  listener_arn      = module.alb.listener_arn
  service_name      = "payments-service"
  path_prefix       = "payments"
  listener_priority = 50
  image_uri         = var.payments_image_uri
  environment       = local.common_env
}
