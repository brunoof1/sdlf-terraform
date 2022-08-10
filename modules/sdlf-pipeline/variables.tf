
variable "stageA_branch" {
  description = "The branch containing feature releases for the StageA Machine. If unique across all pipelines, then git push will only trigger the specific pipeline's CodePipeline. Defaults to master."
  default     = "master"
}

variable "stageB_branch" {
  description = "The branch containing feature releases for the StageB Machine. If unique across all pipelines, then git push will only trigger the specific pipeline's CodePipeline. Defaults to master."
  default     = "master"
}

variable "stageA_statemachine_repository" {
  description = "The name of the repository containing the code for StageA's State Machine."
  default     = "stageA"
}

variable "stageB_statemachine_repository" {
  description = "The name of the repository containing the code for StageB's State Machine."
  default     = "stageB"
}

variable "analytics_bucket" {
  description = "The analytics bucket for the solution"
  default     = null
}

variable "artifacts_bucket" {
  description = "The artifacts bucket for the solution"
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

variable "cfn_bucket" {
  description = "The artifactory bucket used by CodeBuild and CodePipeline"
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

variable "shared_devops_account_id" {
  description = "Shared DevOps Account Id"
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

variable "states_execution_role_arn" {
  description = "role for pipelines (statemachines) to use"
  default     = null
}

variable "elasticsearch_enabled" {
  description = "Boolean for wether ElasticSearch is enabled"
  default     = false
}

variable "kibana_function_arn" {
  description = "specify arn of elasticsearch collation lambda if elasticsearch is enable and not using the default"
  default     = null
}

variable "raw_bucket" {
  default = null
}
