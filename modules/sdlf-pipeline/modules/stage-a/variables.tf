variable "artifacts_bucket" {
  description = "S3 Artifacts bucket"
}

variable "dataset_bucket" {
  description = "The dataset bucket"
}

variable "stage_bucket" {
  description = "The stage bucket"
}

variable "raw_bucket" {
  description = "The stage bucket"
}

variable "application_name" {
  description = "Name of the application (all lowercase, no symbols or spaces)"
}

variable "organization_name" {
  description = "Name of the organization (all lowercase, no symbols or spaces)"
}

variable "team_name" {
  description = "Name of the team owning the pipeline (all lowercase, no symbols or spaces)"
}

variable "permissions_boundary_managed_policy" {
  description = "The permissions boundary IAM Managed policy for the team"
}

variable "pipeline_name" {
  description = "The name of the pipeline (all lowercase, no symbols or spaces)"
}

variable "environment" {
  description = "The name of the environment to deploy the pipeline to"
  default     = "dev"
}

variable "kms_infra_key_id" {
  description = "The team infrastructure KMS key"
}

variable "kms_data_key_id" {
  description = "The team data KMS key"
}

variable "datalake_library_layer_arn" {
  description = "The ARN of the latest Datalake Library Lambda Layer"
}

variable "pip_lib_layer" {
  description = "The ARN of the latest Pip Library Lambda Layer"
}

variable "elasticsearch_enabled" {
  description = "Boolean for wether ElasticSearch is enabled"
  default     = true
}

variable "kibana_function_arn" {
  description = "ARN of the Lambda function that collates logs"
  default     = null
}

variable "states_execution_role_arn" {
  description = "The ARN of the States Execution Role"
}

variable "sns_topic_arn" {
  description = "The team sns topic arn"
}
