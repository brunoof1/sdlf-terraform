########## SSM Parameter Store Values ###############

data "aws_ssm_parameter" "organization" {
  count = var.organization == null ? 1 : 0
  name  = "/SDLF/Misc/Org"
}

data "aws_ssm_parameter" "environment" {
  count = var.environment == null ? 1 : 0
  name  = "/SDLF/Misc/Env"
}

data "aws_ssm_parameter" "application_name" {
  count = var.application_name == null ? 1 : 0
  name  = "/SDLF/Misc/App"
}

data "aws_ssm_parameter" "airflow_bucket" {
  count = var.airflow_bucket == null ? 1 : 0
  name  = "/SDLF/S3/AirflowBucket"
}

data "aws_ssm_parameter" "kms_infra_key_id" {
  name = "/SDLF/KMS/${var.team_name}/InfraKeyId"
}

data "aws_ssm_parameter" "kms_data_key_id" {
  name = "/SDLF/KMS/${var.team_name}/DataKeyId"
}

data "aws_ssm_parameter" "team_permissions_boundary" {
  name = "/SDLF/IAM/${var.team_name}/TeamPermissionsBoundary"
}

data "aws_ssm_parameter" "sns_topic_arn" {
  name = "/SDLF/SNS/${var.team_name}/Notifications"
}

############## Set values ###############

locals {
  application_name                       = var.application_name == null ? data.aws_ssm_parameter.application_name[0].value : var.application_name
  environment                            = var.environment == null ? data.aws_ssm_parameter.environment[0].value : var.environment
  organization                           = var.organization == null ? data.aws_ssm_parameter.organization[0].value : var.organization
  airflow_bucket                         = var.airflow_bucket == null ? data.aws_ssm_parameter.airflow_bucket[0].value : var.airflow_bucket
  team_permissions_boundary              = data.aws_ssm_parameter.team_permissions_boundary.value
  sns_topic_arn                          = data.aws_ssm_parameter.sns_topic_arn.value
  kms_infra_key_id                       = data.aws_ssm_parameter.kms_infra_key_id.value
  kms_data_key_id                        = data.aws_ssm_parameter.kms_data_key_id.value
}

######## MWAA #########
module "pipeline-serasa" {
  count                               = var.airflow_enabled ? 1 : 0
  source                              = "./modules/stage"
  application_name                    = local.application_name
  environment                         = local.environment
  organization_name                   = local.organization
  sns_topic_arn                       = local.sns_topic_arn
  airflow_bucket                      = local.airflow_bucket
  kms_infra_key_id                    = local.kms_infra_key_id
  kms_data_key_id                     = local.kms_data_key_id
  team_name                           = var.team_name
  pipeline_name                       = var.pipeline_name
  permissions_boundary_managed_policy = local.team_permissions_boundary
}