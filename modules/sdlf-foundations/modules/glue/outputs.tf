
output "step1_lambda" {
  value       = aws_lambda_function.step1.arn
  description = "Performs checks and determines which Data Quality job to run"
}

output "job_check_step_lambda" {
  value       = aws_lambda_function.job_check_step.arn
  description = "Checks if job has finished (success/failure)"
}

output "step2_lambda" {
  value       = aws_lambda_function.step2.arn
  description = "Glue Crawler"
}

output "replicate" {
  value       = aws_lambda_function.replicate.arn
  description = "Replicates Glue Catalog Metadata and Data Quality to Octagon Schemas Table"
}
