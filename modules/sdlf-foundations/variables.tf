variable "application_name" {
  description = "Name of the application (all lowercase, no symbols or spaces)"
  default     = "datalake"
}

variable "cloudtrail_enabled" {
  description = "To Deploy CloudTrail, set this to true"
  default     = false
}

variable "cognito_admin_email" {
  description = "Email address of the Cognito admin"
  default     = "nobody@amazon.com"
}

variable "custom_bucket_prefix" {
  description = "S3 Bucket Prefix if different from default. Must be a valid S3 prefix name"
  default     = null
}

variable "elasticsearch_domain_admin_email" {
  description = "Email address of the Elasticsearch domain admin"
  default     = "nobody@amazon.com"
}

variable "elasticsearch_enabled" {
  description = "To Deploy Elasticsearch, set this to true"
  default     = false
}

variable "enable_point_in_time_recovery" {
  description = "Boolean flag to enable/disable point in time recovery for DynamoDB tables"
  default     = true
}

variable "environment" {
  description = "Environment name"
}

variable "number_of_buckets" {
  default     = 3
  description = "Number of data lake buckets (3 or 1)"
}

variable "organization_name" {
  description = "Name of the organization (all lowercase, no symbols or spaces)"
}

variable "sns_notifications_email" {
  description = "Email address for SNS notifications"
  default     = "nobody@amazon.com"
}

variable "shared_devops_account_id" {
  description = "Shared DevOps Account Id"
  default     = null
}

variable "enforce_s3_secure_transport" {
  default     = true
  description = "enforce secure tranport policies on s3 buckets"
}

variable "cross_account_principals" {
  default     = []
  description = "list of aws account principals to allow writing to sdlf s3"
}

variable "enforce_bucket_owner_full_control" {
  default     = false
  description = "enfoce bucket owner full control on s3 buckets"
}

variable "lakeformation_admin_principals" {
  default     = []
  description = "list of iam prinicpals to add as lakeformation principals"
}

variable "lambda_tracing_config_mode" {
  description = "Type of XRay tracing to enable"
  default     = "Active"
  type        = string
  validation {
    condition     = (var.lambda_tracing_config_mode == null || contains(["PassThrough", "Active"], coalesce(var.lambda_tracing_config_mode, "Active")))
    error_message = "Invalid value for var.lambda_tracing_config_mode. Must be one of: PassThrough, Active."
  }
}

variable "lambda_log_retention" {
  description = "The number of days for which logs will be retained in CloudWatch"
  default     = 30
  type        = number
  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.lambda_log_retention)
    error_message = "Invalid value for CloudWatch log group retention. Must be one of: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653."
  }
}

variable "enable_s3_access_logging" {
  description = "Flag to enable/disable S3 Access Logs"
  default     = true
  type        = bool
}

variable "enable_bucket_versioning" {
  description = "Flag to enable/disable S3 versioning"
  default     = true
  type        = bool
}
