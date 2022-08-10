# variables
variable "analytics_bucket" {
  description = "The analytics bucket for the solution"
  default     = null
}

variable "application_name" {
  description = "Name of the application"
  default     = null
}

variable "central_bucket" {
  description = "The central bucket for the solution"
  default     = null
}

variable "environment" {
  description = "Environment name"
  default     = null
}

variable "organization" {
  description = "Name of the organization owning the datalake"
  default     = null
}

variable "dataset_name" {
  description = "The name of the dataset (all lowercase, no symbols or spaces"
}

variable "pipeline_bucket" {
  description = "The artifactory bucket used by CodeBuild and CodePipeline"
  default     = null
}

variable "pipeline_name" {
  description = "The name of the pipeline (all lowercase, no symbols or spaces)"
}

variable "stage_bucket" {
  description = "The stage bucket for the solution"
  default     = null
}

variable "team_name" {
  description = "Name of the team owning the pipeline (all lowercase, no symbols or spaces)"
}

variable "stage_a_transform_name" {
  default = "light_transform_blueprint"
}

variable "stage_b_transform_name" {
  default = "heavy_transform_blueprint"
}
