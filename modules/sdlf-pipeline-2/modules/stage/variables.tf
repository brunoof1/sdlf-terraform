variable "airflow_bucket" {
  description = "The airflow bucket"
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

variable "sns_topic_arn" {
  description = "The team sns topic arn"
}
