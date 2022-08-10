
output "sns_notifications_topic" {
  value       = aws_sns_topic.this.id
  description = "SNS Notifications Topic"
}

output "catalog_lambda" {
  value       = aws_lambda_function.catalog.arn
  description = "Catalogs S3 Put/DeleteObject into ObjectMetadataCatalog DynamoDB table"
}

output "routing_lambda" {
  value       = aws_lambda_function.routing.arn
  description = "Routes S3 PutObject Logs to the relevant StageA Queue"
}

output "catalog_redrive_lambda" {
  value       = aws_lambda_function.catalog_redrive.arn
  description = "Redrives Failed S3 Put/DeleteObject Logs to the catalog queue"
}

output "routing_redrive_lambda" {
  value       = aws_lambda_function.routing_redrive.arn
  description = "Redrives Failed S3 PutObject Logs to the routing queue"
}

output "pipeline_bucket" {
  value       = module.pipeline_bucket.id
  description = "Data Lake Artifactory Bucket"
}

output "ingestion_bucket" {
  value       = local.create_multiple_buckets ? module.raw_bucket[0].id : module.central_bucket[0].id
  description = "Data Lake Ingestion Bucket"
}

output "stage_bucket" {
  value       = local.create_multiple_buckets ? module.stage_bucket[0].id : module.central_bucket[0].id
  description = "Data Lake Stage Bucket"
}

output "analytics_bucket" {
  value       = local.create_multiple_buckets ? module.analytics_bucket[0].id : module.central_bucket[0].id
  description = "Data Lake Analytics Bucket"
}

output "data_quality_bucket" {
  value       = module.data_quality_bucket.id
  description = "Data Quality Bucket"
}
