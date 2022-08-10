variable "application_name" {
  description = "Name of the application"
  default     = null
}

data "aws_ssm_parameter" "application_name" {
  count = var.application_name == null ? 1 : 0
  name  = "/SDLF/Misc/App"
}

data "aws_ssm_parameter" "analytics_bucket" {
  name = "/SDLF/S3/AnalyticsBucket"
}

data "aws_ssm_parameter" "central_bucket" {
  name = "/SDLF/S3/CentralBucket"
}

data "aws_ssm_parameter" "stage_bucket" {
  name = "/SDLF/S3/StageBucket"
}

data "aws_ssm_parameter" "pipeline_bucket" {
  name = "/SDLF/S3/ArtifactsBucket"
}

data "aws_ssm_parameter" "data_quality_state_machine" {
  name = "/SDLF/SM/DataQualityStateMachine"
}

variable "datalake_library_repository_name" {
  description = "Name of the repository containing the code for the Datalake Library."
  default     = "common-datalakeLibrary"
}

variable "datalake_library_lambda_layer_name" {
  description = "Name to give the Lambda Layer containing the Datalake Library"
  default     = "datalake-lib-layer"
}

variable "default_pip_libraries_lambda_layer_name" {
  description = "Name to give the Lambda Layer containing the libraries installed through Pip"
  default     = "default-pip-libraries"
}

variable "enforce_code_coverage" {
  description = "Creates code coverage reports from the unit tests included in `pDatalakeLibraryRepositoryName`. Enforces the minimum threshold specified in `pMinTestCoverage`"
  default     = false
}

variable "environment" {
  description = "Environment Name"
  default     = null
}

data "aws_ssm_parameter" "environment" {
  count = var.environment == null ? 1 : 0
  name  = "/SDLF/Misc/Env"
}

variable "libraries_branch_name" {
  description = "Name of the default branch for Python libraries"
  default     = "master"
}

variable "minimum_test_coverage" {
  description = "[OPTIONAL] The minimum code coverage percentage that is required for the pipeline to proceed to the next stage. Specify only if `enforce_code_coverage` is set to 'true'."
  default     = 80
}

variable "organization_name" {
  description = "Name of the organization owning the datalake"
  default     = null
}

data "aws_ssm_parameter" "organization_name" {
  count = var.organization_name == null ? 1 : 0
  name  = "/SDLF/Misc/Org"
}

variable "pip_libraries_repository_name" {
  description = "The repository containing requirements.txt"
  default     = "common-pipLibrary"
}

variable "sns_notifications_email" {
  description = "Email address for SNS notifications"
  default     = "nobody@amazon.com"
}

variable "team_name" {
  description = "Name of the team (all lowercase, no symbols or spaces)"
}

variable "shared_devops_account_id" {
  description = "Shared DevOps Account Id"
  default     = null
}

data "aws_ssm_parameter" "shared_devops_account_id" {
  count = var.shared_devops_account_id == null ? 1 : 0
  name  = "/SDLF/Misc/DevOpsAccountId"
}

locals {
  application_name           = var.application_name == null ? data.aws_ssm_parameter.application_name[0].value : var.application_name
  analytics_bucket           = data.aws_ssm_parameter.analytics_bucket.value
  central_bucket             = data.aws_ssm_parameter.central_bucket.value
  stage_bucket               = data.aws_ssm_parameter.stage_bucket.value
  pipeline_bucket            = data.aws_ssm_parameter.pipeline_bucket.value
  data_quality_state_machine = data.aws_ssm_parameter.data_quality_state_machine.value
  environment                = var.environment == null ? data.aws_ssm_parameter.environment[0].value : var.environment
  organization_name          = var.organization_name == null ? data.aws_ssm_parameter.organization_name[0].value : var.organization_name
  shared_devops_account_id   = var.shared_devops_account_id == null ? data.aws_ssm_parameter.shared_devops_account_id[0].value : var.shared_devops_account_id
}
