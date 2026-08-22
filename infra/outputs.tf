output "alb_dns_name" {
  description = "Public URL — e.g. http://<this>/kyc/health, http://<this>/lending/campaigns"
  value       = module.alb.alb_dns_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "kinesis_stream" {
  value = module.streaming.stream_name
}

output "data_lake_bucket" {
  value = module.analytics.bucket_name
}

output "vpc_id" {
  value = module.network.vpc_id
}
