variable "application_name" {}
variable "custom_bucket_prefix" {}
variable "environment" {}
variable "kms_key_id" {}
variable "number_of_buckets" {}
variable "organization_name" {}
variable "sns_notifications_email" {}

variable "enforce_s3_secure_transport" {
  default     = true
  description = "enfoce secure tranport policies on s3 buckets"
}

variable "cross_account_principals" {
  default     = []
  description = "list of aws account principals to allow writing to sdlf s3"
}

variable "enforce_bucket_owner_full_control" {
  default     = false
  description = "enfoce bucket owner full control on s3 buckets"
}

variable "lambda_tracing_config_mode" {
  type    = string
  default = "Active"
}

variable "lambda_log_retention" {
  type = number
}

variable "enable_s3_access_logging" {
  type    = bool
  default = true
}

variable "enable_bucket_versioning" {
  type    = bool
  default = true
}
