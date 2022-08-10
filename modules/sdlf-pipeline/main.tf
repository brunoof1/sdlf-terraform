# Description: "Contains all the resources necessary for a single pipeline"

########## SSM Parameter Store Values ###############
data "aws_ssm_parameter" "stage_bucket" {
  count = var.stage_bucket == null ? 1 : 0
  name  = "/SDLF/S3/StageBucket"
}

data "aws_ssm_parameter" "shared_devops_account_id" {
  count = var.shared_devops_account_id == null ? 1 : 0
  name  = "/SDLF/Misc/DevOpsAccountId"
}

data "aws_ssm_parameter" "organization" {
  count = var.organization == null ? 1 : 0
  name  = "/SDLF/Misc/Org"
}

data "aws_ssm_parameter" "environment" {
  count = var.environment == null ? 1 : 0
  name  = "/SDLF/Misc/Env"
}

data "aws_ssm_parameter" "artifacts_bucket" {
  count = var.artifacts_bucket == null ? 1 : 0
  name  = "/SDLF/S3/ArtifactsBucket"
}

data "aws_ssm_parameter" "central_bucket" {
  count = var.central_bucket == null ? 1 : 0
  name  = "/SDLF/S3/CentralBucket"
}

data "aws_ssm_parameter" "application_name" {
  count = var.application_name == null ? 1 : 0
  name  = "/SDLF/Misc/App"
}

data "aws_ssm_parameter" "analytics_bucket" {
  count = var.analytics_bucket == null ? 1 : 0
  name  = "/SDLF/S3/AnalyticsBucket"
}

data "aws_ssm_parameter" "build_datalake_library" {
  name = "/SDLF/CodeBuild/${var.team_name}/BuildDeployDatalakeLibraryLayer"
}

data "aws_ssm_parameter" "cloudwatch_repository_trigger_role_arn" {
  name = "/SDLF/IAM/${var.team_name}/CloudWatchRepositoryTriggerRoleArn"
}

data "aws_ssm_parameter" "codepipeline_role_arn" {
  name = "/SDLF/IAM/${var.team_name}/CodePipelineRoleArn"
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

data "aws_ssm_parameter" "transform_validate_codebuild_job" {
  name = "/SDLF/CodeBuild/${var.team_name}/TransformValidateServerless"
}

data "aws_ssm_parameter" "states_execution_role_arn" {
  name = "/SDLF/IAM/${var.team_name}/StatesExecutionRoleArn"
}

data "aws_ssm_parameter" "pip_lib_layer" {
  name = "/SDLF/Lambda/${var.team_name}/LatestDefaultPipLibraryLayer"
}

data "aws_lambda_layer_version" "pip_lib_layer" {
  layer_name = join(":", slice(split(":", data.aws_ssm_parameter.pip_lib_layer.value), 0, 7))
}

data "aws_ssm_parameter" "datalake_lib_layer" {
  name = "/SDLF/Lambda/${var.team_name}/LatestDatalakeLibraryLayer"
}

data "aws_lambda_layer_version" "datalake_lib_layer" {
  layer_name = join(":", slice(split(":", data.aws_ssm_parameter.datalake_lib_layer.value), 0, 7))
}

data "aws_ssm_parameter" "kibana_function_arn" {
  count = var.elasticsearch_enabled == false ? 0 : var.kibana_function_arn == null ? 1 : 0
  name  = "/SDLF/Lambda/KibanaLambdaArn"
}

############## Set values ###############

locals {
  analytics_bucket                       = var.analytics_bucket == null ? data.aws_ssm_parameter.analytics_bucket[0].value : var.analytics_bucket
  application_name                       = var.application_name == null ? data.aws_ssm_parameter.application_name[0].value : var.application_name
  artifacts_bucket                       = var.artifacts_bucket == null ? data.aws_ssm_parameter.artifacts_bucket[0].value : var.artifacts_bucket
  central_bucket                         = var.central_bucket == null ? data.aws_ssm_parameter.central_bucket[0].value : var.central_bucket
  environment                            = var.environment == null ? data.aws_ssm_parameter.environment[0].value : var.environment
  organization                           = var.organization == null ? data.aws_ssm_parameter.organization[0].value : var.organization
  stage_bucket                           = var.stage_bucket == null ? data.aws_ssm_parameter.stage_bucket[0].value : var.stage_bucket
  shared_devops_account_id               = var.shared_devops_account_id == null ? data.aws_ssm_parameter.shared_devops_account_id[0].value : var.shared_devops_account_id
  build_datalake_library                 = data.aws_ssm_parameter.build_datalake_library.value
  cloudwatch_repository_trigger_role_arn = data.aws_ssm_parameter.cloudwatch_repository_trigger_role_arn.value
  codepipeline_role_arn                  = data.aws_ssm_parameter.codepipeline_role_arn.value
  team_permissions_boundary              = data.aws_ssm_parameter.team_permissions_boundary.value
  sns_topic_arn                          = data.aws_ssm_parameter.sns_topic_arn.value
  transform_validate_codebuild_job       = data.aws_ssm_parameter.transform_validate_codebuild_job.value
  kms_infra_key_id                       = data.aws_ssm_parameter.kms_infra_key_id.value
  kms_data_key_id                        = data.aws_ssm_parameter.kms_data_key_id.value
  kibana_function_arn                    = var.elasticsearch_enabled == false ? null : var.kibana_function_arn == null ? data.aws_ssm_parameter.kibana_function_arn[0].value : var.kibana_function_arn
  states_execution_role_arn              = var.states_execution_role_arn == null ? data.aws_ssm_parameter.states_execution_role_arn.value : var.states_execution_role_arn
}

######## STATE MACHINES #########
module "pipeline-a" {
  source                              = "./modules/stage-a"
  states_execution_role_arn           = local.states_execution_role_arn
  application_name                    = local.application_name
  dataset_bucket                      = local.stage_bucket
  raw_bucket                          = local.central_bucket
  sns_topic_arn                       = local.sns_topic_arn
  organization_name                   = local.organization
  stage_bucket                        = local.stage_bucket
  kms_infra_key_id                    = local.kms_infra_key_id
  kms_data_key_id                     = local.kms_data_key_id
  team_name                           = var.team_name
  pipeline_name                       = var.pipeline_name
  permissions_boundary_managed_policy = local.team_permissions_boundary
  pip_lib_layer                       = data.aws_ssm_parameter.pip_lib_layer.value
  datalake_library_layer_arn          = data.aws_ssm_parameter.datalake_lib_layer.value
  artifacts_bucket                    = local.artifacts_bucket
  elasticsearch_enabled               = var.elasticsearch_enabled
  kibana_function_arn                 = local.kibana_function_arn
  environment                         = local.environment
}

module "pipeline-b" {
  source                              = "./modules/stage-b"
  states_execution_role_arn           = local.states_execution_role_arn
  application_name                    = local.application_name
  dataset_bucket                      = local.stage_bucket
  sns_topic_arn                       = local.sns_topic_arn
  organization_name                   = local.organization
  stage_bucket                        = local.stage_bucket
  kms_infra_key_id                    = local.kms_infra_key_id
  kms_data_key_id                     = local.kms_data_key_id
  team_name                           = var.team_name
  pipeline_name                       = var.pipeline_name
  permissions_boundary_managed_policy = local.team_permissions_boundary
  pip_lib_layer                       = data.aws_ssm_parameter.pip_lib_layer.value
  datalake_library_layer_arn          = data.aws_ssm_parameter.datalake_lib_layer.value
  artifacts_bucket                    = local.artifacts_bucket
  elasticsearch_enabled               = var.elasticsearch_enabled
  kibana_function_arn                 = local.kibana_function_arn
  environment                         = local.environment
}
