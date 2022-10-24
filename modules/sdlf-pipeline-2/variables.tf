variable "application_name" {
  description = "Name of the application"
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

variable "pipeline_name" {
  description = "The name of the pipeline (all lowercase, no symbols or spaces)"
}

variable "airflow_bucket" {
  description = "The airflow bucket for the solution"
  default     = null
}

variable "team_name" {
  description = "Name of the team owning the pipeline (all lowercase, no symbols or spaces)"
}

variable "airflow_enabled" {
  description = "Variable on off"
  default     = true
  type        = bool
}
