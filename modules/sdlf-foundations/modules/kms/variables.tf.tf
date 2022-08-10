
variable "alias" {
  description = "Alias for the KMS key"
}

variable "description" {
  description = "KMS key description"
  default     = null
}

variable "key_policy" {
  description = "JSON of kms key policy"
  default     = null
}

variable "enable_key_rotation" {
  description = "Enable KMS key rotation"
  default     = true
}
