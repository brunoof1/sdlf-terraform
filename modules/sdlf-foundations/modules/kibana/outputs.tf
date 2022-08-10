output "domain_endpoint" {
  description = "ES domain endpoint URL"
  value       = "https://${aws_elasticsearch_domain.this.endpoint}"
}

output "kibana_login_url" {
  description = "Kibana login URL"
  value       = "https://${aws_elasticsearch_domain.this.endpoint}/_plugin/kibana/"
}

output "master_role" {
  description = "IAM role for ES cross account access"
  value       = aws_iam_role.logging_master.arn
}

output "spoke_account_ids" {
  value       = var.spoke_accounts
  description = "Accounts that are allowed to index on ES"
}

output "cluster_size" {
  description = "Cluster size for the deployed ES Domain"
  value       = var.cluster_size
}

output "kibana_lambda_arn" {
  description = "ARN of the Lambda function that collates logs"
  value       = aws_lambda_function.log_streamer.arn
}
