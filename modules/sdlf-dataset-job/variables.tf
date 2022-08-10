# meta
variable "tags" {
  default     = {}
  description = "tags to add to aws resources"
}
variable "team_name" {
  description = "name of the team the dataset belongs to"
}
variable "dataset_name" {
  description = "name of the dataset"
}

# kms
variable "kms_infra_key_id" {
  default     = null
  description = "the team infra kms key id; it will default to an SSM Param lookup at '/SDLF/KMS/{team_name}/InfraKeyId'"
}
variable "kms_data_key_id" {
  default     = null
  description = "the team data kms key id; it will default to an SSM Param lookup at '/SDLF/KMS/{team_name}/DataKeyId'"
}

# glue
variable "artifacts_bucket" {
  default     = null
  description = "the s3 bucket for storing artifacts; it will default to an SSM Param lookup at '/SDLF/S3/ArtifactsBucket'"
}
variable "glue_script_path" {
  default     = null
  description = "the path to the script to upload to s3 for the glue job (local filesystem path)"
}
variable "glue_script_s3_key" {
  default     = null
  description = "the s3 key to upload file as; will default to 'datasets/{dataset_name}/{filename}'"
}
variable "glue_version" {
  default = "2.0"
}
variable "max_retries" {
  default = 0
}
variable "worker_type" {
  default = "G.1X"
}
variable "number_of_workers" {
  default = 10
}
variable "max_concurrent_runs" {
  default = 3
}

# testing/validation
variable "upload_sample_data" {
  default     = false
  description = "if this is set to 'true' terraform will update the example legislators dataset to your raw bucket; only use this setting in a generic test example"
}
