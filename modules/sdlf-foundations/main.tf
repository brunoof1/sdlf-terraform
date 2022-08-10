#############
# SDLF common
#############

############
# lookups
############
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#############
# modules
#############


######## S3 #########
module "s3" {
  source                            = "./modules/s3"
  application_name                  = var.application_name
  custom_bucket_prefix              = var.custom_bucket_prefix
  environment                       = var.environment
  kms_key_id                        = module.kms.kms_key_id
  number_of_buckets                 = var.number_of_buckets
  organization_name                 = var.organization_name
  sns_notifications_email           = var.sns_notifications_email
  enforce_s3_secure_transport       = var.enforce_s3_secure_transport
  cross_account_principals          = var.cross_account_principals
  enforce_bucket_owner_full_control = var.enforce_bucket_owner_full_control
  lambda_tracing_config_mode        = var.lambda_tracing_config_mode
  lambda_log_retention              = var.lambda_log_retention
  enable_bucket_versioning          = var.enable_bucket_versioning
  enable_s3_access_logging          = var.enable_s3_access_logging
}

######## CLOUDTRAIL #########
module "cloudtrail" {
  count                = var.cloudtrail_enabled ? 1 : 0
  source               = "./modules/cloudtrail"
  application_name     = var.application_name
  custom_bucket_prefix = var.custom_bucket_prefix
  environment          = var.environment
  kms_key_arn          = module.kms.kms_key_arn
  organization_name    = var.organization_name
}

######## DYNAMODB #########
module "dynamo" {
  source                        = "./modules/dynamo"
  environment                   = var.environment
  kms_key_arn                   = module.kms.kms_key_arn
  enable_point_in_time_recovery = var.enable_point_in_time_recovery
}

######## GLUE REPLICATION #########
module "glue" {
  source                     = "./modules/glue"
  environment                = var.environment
  kms_key_id                 = module.kms.kms_key_id
  application_name           = var.application_name
  organization_name          = var.organization_name
  data_quality_bucket        = module.s3.data_quality_bucket
  pipeline_bucket            = module.s3.pipeline_bucket
  datalake_admin_role_arn    = aws_iam_role.datalake_admin.arn
  lambda_tracing_config_mode = var.lambda_tracing_config_mode
  lambda_log_retention       = var.lambda_log_retention
}

######## KIBANA STACK #########
module "kibana" {
  count                      = var.elasticsearch_enabled ? 1 : 0
  source                     = "./modules/kibana"
  object_metadata_stream_arn = module.dynamo.object_metadata_stream_arn
  cognito_admin_email        = var.cognito_admin_email
  domain_admin_email         = var.elasticsearch_domain_admin_email
  kms_key_id                 = module.kms.kms_key_id
  lambda_functions = [
    "sdlf-routing",
    "sdlf-catalog",
    "sdlf-routing-redrive",
    "sdlf-catalog-redrive",
    "sdlf-data-quality-initial-check",
    "sdlf-data-quality-check-job",
    "sdlf-glue-replication",
    "sdlf-data-quality-crawl-data"
  ]
  spoke_accounts = []
}

######## KMS #########
module "kms" {
  source              = "./modules/kms"
  alias               = "alias/sdlf-kms-key"
  description         = "Foundations KMS Key"
  enable_key_rotation = true
  key_policy          = data.aws_iam_policy_document.sdlf-kms-key.json
}

######## LAKE FORMATION ADMIN ROLE #########
resource "aws_lakeformation_data_lake_settings" "this" {
  admins = concat([aws_iam_role.datalake_admin.arn], var.lakeformation_admin_principals)
}

resource "aws_iam_role" "datalake_admin" {
  name               = "sdlf-lakeformation-admin"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.datalake_admin.json
}

data "aws_iam_policy_document" "datalake_admin" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
        "glue.amazonaws.com"
      ]
    }
  }
}

locals {
  datalake_admin_policies = [
    "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AWSLakeFormationDataAdmin"
  ]
}

resource "aws_iam_role_policy_attachment" "datalake_admin" {
  for_each   = toset(local.datalake_admin_policies)
  role       = aws_iam_role.datalake_admin.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "lakeformation_admin" {
  name   = "lakeformation_admin"
  role   = aws_iam_role.datalake_admin.id
  policy = data.aws_iam_policy_document.lakeformation_admin.json
}

data "aws_iam_policy_document" "lakeformation_admin" {
  statement {
    sid = "CreateLogGroup"

    actions = [
      "logs:CreateLogGroup",
      "logs:AssociateKmsKey"
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid = "CreateLogStream"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      join(":", ["arn:aws:logs", data.aws_region.current.name, data.aws_caller_identity.current.account_id, "log-group:/aws/lambda/sdlf-*"]),
      join(":", ["arn:aws:logs", data.aws_region.current.name, data.aws_caller_identity.current.account_id, "log-group:/aws/glue/*"])
    ]
  }

  statement {
    sid = "DynamoDBAccess"

    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:PutItem",
      "dynamodb:Scan",
      "dynamodb:UpdateItem"
    ]

    resources = [
      join(":", ["arn:aws:dynamodb", data.aws_region.current.name, data.aws_caller_identity.current.account_id, "table/octagon-*"])
    ]
  }

  statement {
    sid = "SSMAccess"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]

    resources = [
      join(":", ["arn:aws:ssm", data.aws_region.current.name, data.aws_caller_identity.current.account_id, "parameter/SDLF/IAM/DataLakeAdminRoleArn"])
    ]
  }
}


# kms key policy
data "aws_iam_policy_document" "sdlf-kms-key" {

  statement {
    sid = "Allow administration of the key"
    actions = [
      "kms:*"
    ]
    resources = [
      "*"
    ]

    principals {
      type        = "AWS"
      identifiers = [join("", ["arn:aws:iam::", data.aws_caller_identity.current.account_id, ":root"])]
    }
  }

  statement {
    sid = "Allow CloudTrail/CloudWatch alarms access"
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt"
    ]
    resources = [
      "*"
    ]

    principals {
      type = "Service"
      identifiers = [
        "cloudwatch.amazonaws.com",
        "cloudtrail.amazonaws.com"
      ]
    }
  }

  statement {
    sid = "Allow logs access"
    actions = [
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant"
    ]
    resources = [
      "*"
    ]

    principals {
      type = "Service"
      identifiers = [
        join("", ["logs.", data.aws_region.current.name, ".amazonaws.com"])
      ]
    }
  }

  statement {
    sid = "Allow SNS access"
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt"
    ]
    resources = [
      "*"
    ]

    principals {
      type = "AWS"
      identifiers = [
        "*"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"

      values = [
        data.aws_caller_identity.current.account_id
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"

      values = [
        join("", ["sns.", data.aws_region.current.name, ".amazonaws.com"])
      ]
    }
  }

  statement {
    sid = "Allow S3 Events access"
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]
    resources = [
      "*"
    ]

    principals {
      type = "Service"
      identifiers = [
        "s3.amazonaws.com"
      ]
    }
  }

  statement {
    sid = "Allow DynamoDB access"
    actions = [
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant"
    ]

    resources = [
      "*"
    ]

    principals {
      type = "AWS"
      identifiers = [
        "*"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"

      values = [
        data.aws_caller_identity.current.account_id
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"

      values = [
        join("", ["dynamodb.", data.aws_region.current.name, ".amazonaws.com"])
      ]
    }
  }

  statement {
    sid = "Allow Elasticsearch access"
    actions = [
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant"
    ]

    resources = [
      "*"
    ]

    principals {
      type = "AWS"
      identifiers = [
        "*"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"

      values = [
        data.aws_caller_identity.current.account_id
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"

      values = [
        join("", ["es.", data.aws_region.current.name, ".amazonaws.com"])
      ]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"

      values = [
        "true"
      ]
    }
  }
}

######## SSM OUTPUTS #########
resource "aws_ssm_parameter" "organization" {
  name        = "/SDLF/Misc/Org"
  type        = "String"
  value       = var.organization_name
  description = "Name of the Organization owning the datalake"
  overwrite   = true
}

resource "aws_ssm_parameter" "application" {
  name        = "/SDLF/Misc/App"
  type        = "String"
  value       = var.application_name
  description = "Name of the Application"
  overwrite   = true
}

resource "aws_ssm_parameter" "environment" {
  name        = "/SDLF/Misc/Env"
  type        = "String"
  value       = var.environment
  description = "Name of the environment"
  overwrite   = true
}

resource "aws_ssm_parameter" "kibana_lambda_arm" {
  count       = var.elasticsearch_enabled ? 1 : 0
  name        = "/SDLF/Lambda/KibanaLambdaArn"
  type        = "String"
  value       = module.kibana.0.kibana_lambda_arn
  description = "ARN of the Lambda function that collates logs"
  overwrite   = true
}

resource "aws_ssm_parameter" "shared_devops_account_id" {
  name        = "/SDLF/Misc/DevOpsAccountId"
  type        = "String"
  value       = var.shared_devops_account_id == null ? data.aws_caller_identity.current.account_id : var.shared_devops_account_id
  description = "Shared DevOps Account Id"
  overwrite   = true
}

resource "aws_ssm_parameter" "datalake_admin_role_arn" {
  name        = "/SDLF/IAM/DataLakeAdminRoleArn"
  type        = "String"
  value       = aws_iam_role.datalake_admin.arn
  description = "Lake Formation Data Lake Admin Role"
  overwrite   = true
}
