
variable "application_name" {
  type = string
}

variable "data_quality_bucket" {
  type = string
}

variable "datalake_admin_role_arn" {
  type = string
}

variable "environment" {
  type = string
}

variable "kms_key_id" {
  type = string
}

variable "organization_name" {
  type = string
}

variable "pipeline_bucket" {
  type = string
}

variable "lambda_tracing_config_mode" {
  type = string
}

variable "lambda_runtime" {
  default = "python3.7"
}

variable "lambda_handler" {
  default = "lambda_function.lambda_handler"
}

variable "lambda_log_retention" {
  type = number
}
