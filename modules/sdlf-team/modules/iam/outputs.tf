
output "codepipeline_role_arn" {
  description = "The ARN of the role used by CodePipeline"
  value       = aws_iam_role.codepipeline.arn
}

output "codebuild_publish_layer_role_arn" {
  description = "The ARN of the role used by CodeBuild to publish layers"
  value       = aws_iam_role.codebuild_publish_layer.arn
}

output "cicd_codebuild_role_arn" {
  description = "The ARN of the CICD role used by CodeBuild"
  value       = aws_iam_role.cicd_codebuild.arn
}

output "codebuild_service_role_arn" {
  value       = aws_iam_role.codebuild_service.arn
  description = "The ARN of the service role used by CodeBuild"
}

output "cloudwatch_repository_trigger_role_arn" {
  description = "The ARN of the CloudWatch Event role that triggers CodePipeline from CodeCommit"
  value       = aws_iam_role.cloudwatch_repository_trigger.arn
}

output "states_execution_role_arn" {
  description = "The ARN of the State Machine role"
  value       = aws_iam_role.states_execution.arn
}

output "transform_validate_role_arn" {
  description = "The ARN of the Transform Validation role"
  value       = aws_iam_role.transform_validate.arn
}

output "datalake_crawler_role_arn" {
  description = "The ARN of the Glue Crawler role"
  value       = aws_iam_role.datalake_crawler.arn
}
