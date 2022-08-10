variable "analytics_bucket" {}
variable "application_name" {}
variable "central_bucket" {}
variable "environment" {}
variable "kms_infra_key_id" {}
variable "organization_name" {}
variable "pipeline_bucket" {}
variable "shared_devops_account_id" {}
variable "stage_bucket" {}
variable "team_name" {
  default = "engineering"
}

variable "codecommit_role_arn" {
  default = null
}

variable "cloudwatch_repository_trigger_role_arn" {
  description = "The name of the CloudWatch Event role that triggers CodePipeline from CodeCommit"
}

variable "codebuild_publish_layer_role_arn" {
  description = "The ARN of the role used by CodeBuild to publish layers"
}

variable "cicd_codebuild_role_arn" {
  description = "The ARN of the CICD role used by CodeBuild"
}

variable "codebuild_service_role_arn" {
  description = "The ARN of the service role used by CodeBuild"
}

variable "codepipeline_role_arn" {
  description = "The ARN of the role used by CodePipeline"
}

variable "datalake_library_repository_name" {
  default = "common-datalakeLibrary"
}
variable "datalake_libs_lambda_layer_name" {}
variable "default_pip_libraries_lambda_layer_name" {}
variable "libraries_branch_name" {
  default = "dev"
}
variable "minimum_test_coverage" {
  description = "[OPTIONAL] The minimum code coverage percentage that is required for the pipeline to continue to the next stage. Specify only if `run_code_coverage` is set to True."
  default     = null
}
variable "pip_libraries_repository_name" {
  default = "common-pipLibrary"
}
variable "run_code_coverage" {
  description = "Creates code coverage reports from the unit tests included in `pDatalakeLibraryRepositoryName`. Enforces the minimum threshold specified in `pMinimumTestCoverage`"
  default     = false
}
variable "sns_notifications_email" {
  default = "nobody@amazon.com"
}
variable "transform_validate_role_arn" {
  description = "The ARN of the Transform Validation role"
}
