# Elasticsearch parameters
variable "domain_name" {
  description = "Name for the Amazon ES domain that this template will create. Domain names must start with a lowercase letter and must be between 3 and 28 characters. Valid characters are a-z (lowercase only), 0-9."
  default     = "sdlf"
}

variable "domain_admin_email" {
  description = "E-mail address of the Elasticsearch admin"
}

variable "cognito_admin_email" {
  description = "E-mail address of the Cognito admin"
}

variable "cluster_size" {
  description = "Amazon ES cluster size; example sizes: small (4 data nodes), medium (6 data nodes), large (6 data nodes)"
  default     = "small"
}

variable "demo_template" {
  description = "Deploy template for sample data and logs?"
  default     = false
}

variable "spoke_accounts" {
  description = "Account IDs which you want to allow for centralized logging"
  type        = list(any)
  default     = null
}

# SDLF specific parameters
variable "lambda_functions" {
  description = "name of lambda functions with logs to stream to elasticsearch"
  default     = []
}

variable "kms_key_id" {}

# VPC CIDR for sample sources
variable "demo_vpc" {
  description = "CIDR for VPC with sample sources"
  default     = "10.250.0.0/16"
}

variable "demo_subnet" {
  description = "IP address range for subnet with sample web server"
  default     = "10.250.250.0/24"
}

variable "object_metadata_stream_arn" {
  description = "Dynamo Stream Arn for Octagon Object Metadata Table"
}
