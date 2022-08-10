output "ingestion_bucket" {
  value       = module.s3.ingestion_bucket
  description = "Data Lake Ingestion Bucket"
}
