# sdlf = team module


######## KMS #########
module "kms" {
  source                   = "./modules/kms"
  environment              = local.environment
  shared_devops_account_id = local.shared_devops_account_id
  team_name                = var.team_name
}

######## IAM #########
module "iam" {
  source                     = "./modules/iam"
  analytics_bucket           = local.analytics_bucket
  application_name           = local.application_name
  central_bucket             = local.central_bucket
  data_quality_state_machine = local.data_quality_state_machine
  environment                = local.environment
  kms_infra_key_arn          = module.kms.infra_key_arn
  kms_data_key_arn           = module.kms.data_key_arn
  organization_name          = local.organization_name
  pipeline_bucket            = local.pipeline_bucket
  shared_devops_account_id   = local.shared_devops_account_id
  stage_bucket               = local.stage_bucket
  team_name                  = var.team_name
}

module "cicd" {
  source                                  = "./modules/cicd"
  analytics_bucket                        = local.analytics_bucket
  application_name                        = var.application_name
  central_bucket                          = local.central_bucket
  cloudwatch_repository_trigger_role_arn  = module.iam.cloudwatch_repository_trigger_role_arn
  codebuild_publish_layer_role_arn        = module.iam.codebuild_publish_layer_role_arn
  cicd_codebuild_role_arn                 = module.iam.cicd_codebuild_role_arn
  codebuild_service_role_arn              = module.iam.codebuild_service_role_arn
  codepipeline_role_arn                   = module.iam.codepipeline_role_arn
  datalake_library_repository_name        = var.datalake_library_repository_name
  datalake_libs_lambda_layer_name         = var.datalake_library_lambda_layer_name
  default_pip_libraries_lambda_layer_name = var.default_pip_libraries_lambda_layer_name
  environment                             = local.environment
  kms_infra_key_id                        = module.kms.infra_key_id
  libraries_branch_name                   = var.libraries_branch_name
  minimum_test_coverage                   = var.minimum_test_coverage
  organization_name                       = local.organization_name
  pipeline_bucket                         = local.pipeline_bucket
  shared_devops_account_id                = local.shared_devops_account_id
  stage_bucket                            = local.stage_bucket
  team_name                               = var.team_name
  pip_libraries_repository_name           = var.pip_libraries_repository_name
  run_code_coverage                       = var.enforce_code_coverage
  sns_notifications_email                 = var.sns_notifications_email
  transform_validate_role_arn             = module.iam.transform_validate_role_arn
}


locals {
  s3_paths_for_lakeformation_grants = [
    "arn:aws:s3:::${local.central_bucket}/${var.team_name}",
    "arn:aws:s3:::${local.stage_bucket}/pre-stage/${var.team_name}",
    "arn:aws:s3:::${local.stage_bucket}/post-stage/${var.team_name}",
    "arn:aws:s3:::${local.analytics_bucket}/${var.team_name}"
  ]
}

resource "aws_lakeformation_permissions" "datalake_crawler_role_perms_0" {
  principal   = module.iam.datalake_crawler_role_arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = local.s3_paths_for_lakeformation_grants[0]
  }
}

resource "aws_lakeformation_permissions" "datalake_crawler_role_perms_1" {
  principal   = module.iam.datalake_crawler_role_arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = local.s3_paths_for_lakeformation_grants[1]
  }
}

resource "aws_lakeformation_permissions" "datalake_crawler_role_perms_2" {
  principal   = module.iam.datalake_crawler_role_arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = local.s3_paths_for_lakeformation_grants[2]
  }
}

resource "aws_lakeformation_permissions" "datalake_crawler_role_perms_3" {
  principal   = module.iam.datalake_crawler_role_arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = local.s3_paths_for_lakeformation_grants[3]
  }
}
