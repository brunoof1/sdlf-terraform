variable "bucket_name" {
  description = "name of s3 bucket"
  type        = string
}

variable "sse_algorithm" {
  description = "encryption algorithm to use"
  default     = "AES256"
  type        = string
}

variable "enable_encryption" {
  default = true
}

variable "s3_access_logs_bucket" {
  description = "bucket id to use for s3 access logs; setting this variable will enable access logging"
  default     = null
  type        = string
}

variable "s3_access_logs_target_prefix" {
  description = "s3 prefix to store s3 access logs for this bucket"
  default     = null
  type        = string
}

variable "enable_bucket_versioning" {
  description = "enable s3 bucket versioning"
  default     = false
  type        = bool
}

variable "block_public_access" {
  description = "block public access for s3 bucket"
  default     = true
  type        = bool
}

variable "enable_lakeformation" {
  description = "create lakeformation resource for s3 bucket"
  default     = false
  type        = bool
}

variable "bucket_acl" {
  description = "name of bucket acl to set"
  default     = null
  type        = string
}