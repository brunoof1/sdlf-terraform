variable "application_name" {
  type = string
}

variable "cloudwatch_logs_retention" {
  default     = 30
  description = "The number of days log events are kept in CloudWatch Logs"
}

variable "custom_bucket_prefix" {
  type    = string
  default = null
}

variable "environment" {
  type = string
}

variable "external_trail_bucket" {
  description = "Optional The name of the Amazon S3 bucket where CloudTrail publishes log files. If empty, the Amazon S3 bucket is created for you."
  default     = null
}

variable "kms_key_arn" {
  type = string
}

variable "log_file_prefix" {
  description = "Optional The log file prefix."
  default     = null
}

variable "organization_name" {
  type = string
}

variable "s3_data_events" {
  description = "Record data events of all S3 buckets"
  default     = false
}

variable "cloudtrail_name" {
  description = "name for trail"
  default     = null
}
