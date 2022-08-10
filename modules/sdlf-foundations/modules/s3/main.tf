# S3 and associated Lambda/SQS Resources to be created by the common stack

# lookups
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_kms_key" "this" {
  key_id = var.kms_key_id
}

locals {
  create_multiple_buckets  = var.number_of_buckets > 1 ? true : false
  create_single_bucket     = var.number_of_buckets == 1 ? true : false
  use_custom_bucket_prefix = var.custom_bucket_prefix == null ? false : true
  lambda_runtime           = "python3.7"
  lambda_handler           = "lambda_function.lambda_handler"
  kms_key_arn              = data.aws_kms_key.this.arn
  bucket_policy_principals = concat([join(":", ["arn:aws:iam:", data.aws_caller_identity.current.account_id, "root"])], var.cross_account_principals)
}

####### S3 Buckets #########
locals {
  logs_bucket_name = local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "access-logs"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "access-logs"])
}

resource "aws_s3_bucket" "log_bucket" {
  count  = var.enable_s3_access_logging == true ? 1 : 0
  bucket = local.logs_bucket_name
}

resource "aws_s3_bucket_acl" "log_bucket" {
  count  = var.enable_s3_access_logging == true ? 1 : 0
  bucket = aws_s3_bucket.log_bucket[0].id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  count  = var.enable_s3_access_logging == true ? 1 : 0
  bucket = aws_s3_bucket.log_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "log_bucket" {
  bucket        = aws_s3_bucket.log_bucket[0].id
  target_bucket = local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "access-logs"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "access-logs"])
  target_prefix = local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "access-logs/"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "access-logs/"])
}

resource "aws_s3_bucket_versioning" "log_bucket" {
  count  = var.enable_bucket_versioning == true ? 1 : 0
  bucket = aws_s3_bucket.log_bucket[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket" {
  count                   = var.enable_s3_access_logging == true ? 1 : 0
  bucket                  = aws_s3_bucket.log_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


data "aws_iam_policy_document" "log_bucket" {
  count = var.enable_s3_access_logging ? 1 : 0

  dynamic "statement" {
    for_each = var.enforce_s3_secure_transport ? [""] : []

    content {
      actions = [
        "s3:*"
      ]
      resources = [
        aws_s3_bucket.log_bucket[0].arn
      ]
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }
      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "log_bucket" {
  count  = var.enable_s3_access_logging == true ? 1 : 0
  bucket = aws_s3_bucket.log_bucket[0].id
  policy = data.aws_iam_policy_document.log_bucket[0].json
}

locals {
  pipeline_bucket_name = local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "artifactory"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "artifactory"])
}
module "pipeline_bucket" {
  source                       = "../../../services/s3"
  bucket_name                  = local.pipeline_bucket_name
  s3_access_logs_bucket        = var.enable_s3_access_logging ? local.logs_bucket_name : null
  s3_access_logs_target_prefix = var.enable_s3_access_logging ? join("", [local.pipeline_bucket_name, "/"]) : null
  enable_bucket_versioning     = var.enable_bucket_versioning
}

data "aws_iam_policy_document" "pipeline" {

  dynamic "statement" {
    for_each = var.enforce_s3_secure_transport == true ? [""] : []

    content {
      actions = [
        "s3:*"
      ]
      resources = [
        module.pipeline_bucket.arn
      ]
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }
      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "pipeline" {
  bucket = module.pipeline_bucket.id
  policy = data.aws_iam_policy_document.pipeline.json
}

module "central_bucket" {
  count                        = local.create_single_bucket ? 1 : 0
  source                       = "../../../services/s3"
  bucket_name                  = local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "central"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "central"])
  s3_access_logs_bucket        = var.enable_s3_access_logging ? local.logs_bucket_name : null
  s3_access_logs_target_prefix = var.enable_s3_access_logging ? local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "central/"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "central/"]) : null
  enable_bucket_versioning     = var.enable_bucket_versioning
  enable_lakeformation         = true
}

resource "aws_s3_bucket_notification" "central" {
  count  = local.create_single_bucket ? 1 : 0
  bucket = module.central_bucket[0].id

  queue {
    queue_arn = aws_sqs_queue.catalog.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}

module "raw_bucket" {
  count                        = local.create_multiple_buckets ? 1 : 0
  source                       = "../../../services/s3"
  bucket_name                  = local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "raw"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "raw"])
  s3_access_logs_bucket        = var.enable_s3_access_logging ? local.logs_bucket_name : null
  s3_access_logs_target_prefix = var.enable_s3_access_logging ? local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "raw/"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "raw/"]) : null
  enable_bucket_versioning     = var.enable_bucket_versioning
  enable_lakeformation         = true
}

resource "aws_s3_bucket_policy" "raw" {
  bucket = module.raw_bucket[0].id
  policy = data.aws_iam_policy_document.raw_bucket_policy.json
}

data "aws_iam_policy_document" "raw_bucket_policy" {

  dynamic "statement" {
    for_each = var.enforce_s3_secure_transport == true ? [""] : []

    content {
      actions = [
        "s3:*"
      ]
      resources = [
        module.raw_bucket[0].arn
      ]
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }
      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = [
      join("", [module.raw_bucket[0].arn, "/*"]),
      module.raw_bucket[0].arn
    ]
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = local.bucket_policy_principals
    }
  }

  dynamic "statement" {
    for_each = var.enforce_bucket_owner_full_control == true ? [""] : []

    content {
      actions = [
        "s3:PutObject"
      ]
      resources = [
        join("", [module.raw_bucket[0].arn, "/*"])
      ]
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = local.bucket_policy_principals
      }

      condition {
        test     = "StringEquals"
        variable = "s3:x-amz-acl"
        values   = ["bucket-owner-full-control"]
      }
    }
  }
}

resource "aws_s3_bucket_notification" "raw" {
  count  = local.create_multiple_buckets ? 1 : 0
  bucket = module.raw_bucket.0.id

  queue {
    queue_arn = aws_sqs_queue.catalog.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}


module "stage_bucket" {
  count                        = local.create_multiple_buckets ? 1 : 0
  source                       = "../../../services/s3"
  bucket_name                  = local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "stage"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "stage"])
  s3_access_logs_bucket        = var.enable_s3_access_logging ? local.logs_bucket_name : null
  s3_access_logs_target_prefix = var.enable_s3_access_logging ? local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "stage/"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "stage/"]) : null
  enable_bucket_versioning     = var.enable_bucket_versioning
  enable_lakeformation         = true
}


data "aws_iam_policy_document" "stage_bucket_policy" {

  dynamic "statement" {
    for_each = var.enforce_s3_secure_transport == true ? [""] : []

    content {
      actions = [
        "s3:*"
      ]
      resources = [
        module.stage_bucket[0].arn
      ]
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }
      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "stage" {
  bucket = module.stage_bucket[0].id
  policy = data.aws_iam_policy_document.stage_bucket_policy.json
}

resource "aws_s3_bucket_notification" "stage" {
  count  = local.create_multiple_buckets ? 1 : 0
  bucket = module.stage_bucket.0.id

  queue {
    queue_arn = aws_sqs_queue.catalog.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}


module "analytics_bucket" {
  count                        = local.create_multiple_buckets ? 1 : 0
  source                       = "../../../services/s3"
  bucket_name                  = local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "analytics"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "analytics"])
  s3_access_logs_target_prefix = var.enable_s3_access_logging ? local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "analytics/"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "analytics/"]) : null
  enable_bucket_versioning     = var.enable_bucket_versioning
  enable_lakeformation         = true
}

data "aws_iam_policy_document" "analytics_bucket_policy" {

  dynamic "statement" {
    for_each = var.enforce_s3_secure_transport == true ? [""] : []

    content {
      actions = [
        "s3:*"
      ]
      resources = [
        module.analytics_bucket[0].arn
      ]
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }
      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "analytics" {
  bucket = module.analytics_bucket[0].id
  policy = data.aws_iam_policy_document.analytics_bucket_policy.json
}

resource "aws_s3_bucket_notification" "analytics" {
  count  = local.create_multiple_buckets ? 1 : 0
  bucket = module.analytics_bucket.0.id

  queue {
    queue_arn = aws_sqs_queue.catalog.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}

module "data_quality_bucket" {
  source                       = "../../../services/s3"
  bucket_name                  = local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "data-quality"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "data-quality"])
  s3_access_logs_bucket        = var.enable_s3_access_logging ? local.logs_bucket_name : null
  s3_access_logs_target_prefix = var.enable_s3_access_logging ? local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "data-quality/"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "data-quality/"]) : null
  enable_bucket_versioning     = var.enable_bucket_versioning
  enable_lakeformation         = true
}

data "aws_iam_policy_document" "data_quality_bucket_policy" {

  dynamic "statement" {
    for_each = var.enforce_s3_secure_transport == true ? [""] : []

    content {
      actions = [
        "s3:*"
      ]
      resources = [
        module.data_quality_bucket.arn
      ]
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }
      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "data_quality" {
  bucket = module.data_quality_bucket.id
  policy = data.aws_iam_policy_document.data_quality_bucket_policy.json
}


module "athena_results_bucket" {
  source                       = "../../../services/s3"
  bucket_name                  = local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "athena-results"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "athena-results"])
  s3_access_logs_bucket        = var.enable_s3_access_logging ? local.logs_bucket_name : null
  s3_access_logs_target_prefix = var.enable_s3_access_logging ? local.use_custom_bucket_prefix ? join("-", [var.custom_bucket_prefix, "athena-results/"]) : join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "athena-results/"]) : null
  enable_bucket_versioning     = var.enable_bucket_versioning
}

data "aws_iam_policy_document" "athena_results_bucket_policy" {

  dynamic "statement" {
    for_each = var.enforce_s3_secure_transport == true ? [""] : []

    content {
      actions = [
        "s3:*"
      ]
      resources = [
        module.athena_results_bucket.arn
      ]
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }
      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "athena_results" {
  bucket = module.athena_results_bucket.id
  policy = data.aws_iam_policy_document.athena_results_bucket_policy.json
}

######## SNS #########
resource "aws_sns_topic" "this" {
  name              = "sdlf-notifications"
  kms_master_key_id = var.kms_key_id
}

resource "aws_sns_topic_policy" "this" {
  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "sdlf-notifications"

  statement {
    effect = "Allow"
    resources = [
      aws_sns_topic.this.arn,
    ]
    actions = [
      "sns:Publish"
    ]

    principals {
      type = "Service"
      identifiers = [
        "cloudwatch.amazonaws.com",
        "cloudtrail.amazonaws.com"
      ]
    }
  }
}

######## Lambda & SQS #########

resource "aws_sqs_queue" "catalog" {
  name                       = join("-", ["sdlf", "catalog", "queue"])
  visibility_timeout_seconds = 60
  kms_master_key_id          = var.kms_key_id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.catalog_deadletter.arn
    maxReceiveCount     = 1
  })
}

resource "aws_sqs_queue" "catalog_deadletter" {
  name                       = join("-", ["sdlf", "catalog", "dlq"])
  visibility_timeout_seconds = 60
  message_retention_seconds  = 1209600
  kms_master_key_id          = var.kms_key_id
}

resource "aws_sqs_queue" "routing" {
  name                       = join("-", ["sdlf", "routing", "queue"])
  visibility_timeout_seconds = 60
  kms_master_key_id          = var.kms_key_id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.routing_deadletter.arn
    maxReceiveCount     = 1
  })
}

resource "aws_sqs_queue" "routing_deadletter" {
  name                       = join("-", ["sdlf", "routing", "dlq"])
  visibility_timeout_seconds = 60
  message_retention_seconds  = 1209600
  kms_master_key_id          = var.kms_key_id
}

resource "aws_lambda_event_source_mapping" "catalog" {
  event_source_arn = aws_sqs_queue.catalog.arn
  function_name    = aws_lambda_function.catalog.arn
  batch_size       = 10
  enabled          = true
}

resource "aws_lambda_event_source_mapping" "routing" {
  event_source_arn = aws_sqs_queue.routing.arn
  function_name    = aws_lambda_function.routing.arn
  batch_size       = 10
  enabled          = true
}


# bundle code
data "archive_file" "catalog" {
  type        = "zip"
  source_file = "${path.module}/lambda/catalog/src/lambda_function.py"
  output_path = "${path.module}/lambda/catalog/catalog.zip"
}

resource "aws_lambda_function" "catalog" {
  function_name    = join("-", ["sdlf", "catalog"])
  description      = "Catalogs S3 Put and Delete to ObjectMetaDataCatalog"
  role             = aws_iam_role.routing.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 256
  timeout          = 60
  source_code_hash = data.archive_file.catalog.output_base64sha256
  filename         = data.archive_file.catalog.output_path

  environment {
    variables = {
      ENV           = var.environment,
      NUM_BUCKETS   = var.number_of_buckets
      ROUTING_QUEUE = aws_sqs_queue.routing.name
    }
  }

  dynamic "tracing_config" {
    for_each = var.lambda_tracing_config_mode == null ? [] : [1]
    content {
      mode = var.lambda_tracing_config_mode
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "catalog" {
  alarm_name          = "sdlf-catalog"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "5"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  unit                = "Count"
  alarm_description   = "Catalog Lambda Alarm"
  alarm_actions       = [aws_sns_topic.this.arn]
  dimensions = {
    Name  = "FunctionName"
    Value = aws_lambda_function.catalog.arn
  }
}

# bundle code
data "archive_file" "routing" {
  type        = "zip"
  source_file = "${path.module}/lambda/routing/src/lambda_function.py"
  output_path = "${path.module}/lambda/routing/routing.zip"
}


resource "aws_lambda_function" "routing" {
  function_name    = join("-", ["sdlf", "routing"])
  description      = "Routes S3 PutObject Logs to the relevant StageA Queue"
  role             = aws_iam_role.routing.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 256
  timeout          = 60
  source_code_hash = data.archive_file.routing.output_base64sha256
  filename         = data.archive_file.routing.output_path

  environment {
    variables = {
      ENV         = var.environment,
      NUM_BUCKETS = var.number_of_buckets,
      ORG         = var.organization_name,
      APP         = var.application_name,
      ACCOUNT_ID  = data.aws_caller_identity.current.account_id

    }
  }

  dynamic "tracing_config" {
    for_each = var.lambda_tracing_config_mode == null ? [] : [1]
    content {
      mode = var.lambda_tracing_config_mode
    }
  }
}

resource "aws_cloudwatch_log_group" "routing" {
  name              = join("", ["/aws/lambda/", "sdlf-", "routing"])
  kms_key_id        = data.aws_kms_key.this.arn
  retention_in_days = var.lambda_log_retention
}

resource "aws_cloudwatch_metric_alarm" "routing" {
  alarm_name          = "sdlf-routing"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "5"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  unit                = "Count"
  alarm_description   = "Routing Lambda Alarm"
  alarm_actions       = [aws_sns_topic.this.arn]
  dimensions = {
    Name  = "FunctionName"
    Value = aws_lambda_function.catalog.arn
  }
}

# bundle code
data "archive_file" "catalog_redrive" {
  type        = "zip"
  source_file = "${path.module}/lambda/catalog-redrive/src/lambda_function.py"
  output_path = "${path.module}/lambda/catalog-redrive/catalog-redrive.zip"
}

resource "aws_lambda_function" "catalog_redrive" {
  function_name    = join("-", ["sdlf", "catalog", "redrive"])
  description      = "Redrives Failed S3 Put/Delete to Catalog Lambda"
  role             = aws_iam_role.routing.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 256
  timeout          = 60
  source_code_hash = data.archive_file.catalog_redrive.output_base64sha256
  filename         = data.archive_file.catalog_redrive.output_path

  environment {
    variables = {
      QUEUE = split(":", aws_sqs_queue.catalog.arn)[5],
      DLQ   = split(":", aws_sqs_queue.catalog_deadletter.arn)[5]
    }
  }

  dynamic "tracing_config" {
    for_each = var.lambda_tracing_config_mode == null ? [] : [1]
    content {
      mode = var.lambda_tracing_config_mode
    }
  }
}

resource "aws_cloudwatch_log_group" "catalog_redrive" {
  name              = join("", ["/aws/lambda/", "sdlf-catalog-redrive"])
  kms_key_id        = data.aws_kms_key.this.arn
  retention_in_days = var.lambda_log_retention
}

# bundle code
data "archive_file" "routing_redrive" {
  type        = "zip"
  source_file = "${path.module}/lambda/routing-redrive/src/lambda_function.py"
  output_path = "${path.module}/lambda/routing-redrive/routing-redrive.zip"
}

resource "aws_lambda_function" "routing_redrive" {
  function_name    = join("-", ["sdlf", "routing", "redrive"])
  description      = "Redrives Failed S3 PutObject Logs to the routing queue"
  role             = aws_iam_role.routing.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 256
  timeout          = 60
  source_code_hash = data.archive_file.routing_redrive.output_base64sha256
  filename         = data.archive_file.routing_redrive.output_path

  environment {
    variables = {
      QUEUE = split(":", aws_sqs_queue.routing.arn)[5],
      DLQ   = split(":", aws_sqs_queue.routing_deadletter.arn)[5]
    }
  }

  dynamic "tracing_config" {
    for_each = var.lambda_tracing_config_mode == null ? [] : [1]
    content {
      mode = var.lambda_tracing_config_mode
    }
  }
}

resource "aws_cloudwatch_log_group" "routing_redrive" {
  name              = join("", ["/aws/lambda/", "sdlf-routing-redrive"])
  kms_key_id        = data.aws_kms_key.this.arn
  retention_in_days = var.lambda_log_retention
}

resource "aws_sqs_queue_policy" "catalog" {
  queue_url = aws_sqs_queue.catalog.id
  policy    = data.aws_iam_policy_document.catalog.json
}

data "aws_iam_policy_document" "catalog" {
  statement {
    actions = [
      "sqs:SendMessage",
    ]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    resources = [
      aws_sqs_queue.catalog.arn
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = local.create_multiple_buckets ? [module.raw_bucket[0].arn, module.stage_bucket[0].arn, module.analytics_bucket[0].arn] : [module.central_bucket[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sqs_queue_policy" "routing" {
  queue_url = aws_sqs_queue.routing.id
  policy    = data.aws_iam_policy_document.routing.json
}

data "aws_iam_policy_document" "routing" {
  statement {
    actions = [
      "sqs:SendMessage",
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.routing.arn]
    }

    resources = [
      aws_sqs_queue.routing.arn
    ]
  }
}

resource "aws_iam_role" "routing" {
  name               = "sdlf-routing"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}


data "aws_iam_policy_document" "routing_lambda" {
  statement {
    actions = [
      "logs:CreateLogGroup"
    ]

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/sdlf-*"
    ]
  }

  statement {
    actions = [
      "sqs:DeleteMessage",
      "sqs:DeleteMessageBatch",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueues",
      "sqs:ListDeadLetterSourceQueues",
      "sqs:ListQueueTags",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
      "sqs:SendMessageBatch"
    ]

    resources = [
      "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-*"
    ]
  }

  statement {
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:GetRecords",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWriteItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem",
      "dynamodb:PutItem"
    ]

    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/octagon-*"
    ]
  }

  statement {
    actions = [
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant"
    ]

    resources = [
      local.kms_key_arn
    ]
  }

  dynamic "statement" {
    for_each = var.lambda_tracing_config_mode == null ? [] : [1]
    content {
      actions = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets",
        "xray:GetSamplingStatisticSummaries"
      ]

      resources = [
        "*"
      ]
    }
  }
}
resource "aws_iam_role_policy" "routing" {
  name = "sdlf-routing"
  role = aws_iam_role.routing.id

  policy = data.aws_iam_policy_document.routing_lambda.json
}

resource "aws_cloudwatch_event_rule" "cicd_foundations" {
  name          = "sdlf-cicd-foundations-failure"
  description   = "Notify data lake admins of foundations CICD pipeline failure"
  is_enabled    = true
  event_pattern = <<EOF
{
  "source": [
    "aws.codepipeline"
  ],
  "detail-type": [
    "CodePipeline Pipeline Execution State Change"
  ],
  "detail": {
    "state": [
      "FAILED"
    ],
    "pipeline": [
      "arn:aws:codepipeline:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-cicd-foundations"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_rule" "cicd_team" {
  name          = "sdlf-cicd-team-failure"
  description   = "Notify data lake admins of team CICD pipeline failure"
  is_enabled    = true
  event_pattern = <<EOF
{
  "source": [
    "aws.codepipeline"
  ],
  "detail-type": [
    "CodePipeline Pipeline Execution State Change"
  ],
  "detail": {
    "state": [
      "FAILED"
    ],
    "pipeline": [
      "arn:aws:codepipeline:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-cicd-team"
    ]
  }
}
EOF
}

####### SSM #######

resource "aws_ssm_parameter" "artifact_bucket" {
  name        = "/SDLF/S3/ArtifactsBucket"
  type        = "String"
  value       = module.pipeline_bucket.id
  description = "Name of the Artifacts S3 Bucket"
  overwrite   = true
}

resource "aws_ssm_parameter" "central_bucket" {
  name        = "/SDLF/S3/CentralBucket"
  type        = "String"
  value       = local.create_multiple_buckets ? module.raw_bucket[0].id : module.central_bucket[0].id
  description = "Name of the Central S3 Bucket"
  overwrite   = true
}

resource "aws_ssm_parameter" "stage_bucket" {
  name        = "/SDLF/S3/StageBucket"
  type        = "String"
  value       = local.create_multiple_buckets ? module.stage_bucket[0].id : module.central_bucket[0].id
  description = "Name of the Stage S3 Bucket"
  overwrite   = true
}

resource "aws_ssm_parameter" "analytics_bucket" {
  name        = "/SDLF/S3/AnalyticsBucket"
  type        = "String"
  value       = local.create_multiple_buckets ? module.analytics_bucket[0].id : module.central_bucket[0].id
  description = "Name of the Analytics S3 Bucket"
  overwrite   = true
}

resource "aws_ssm_parameter" "data_quality_bucket" {
  name        = "/SDLF/S3/DataQualityBucket"
  type        = "String"
  value       = module.data_quality_bucket.id
  description = "Name of the Data Quality S3 Bucket"
  overwrite   = true
}

resource "aws_ssm_parameter" "athena_bucket" {
  name        = "/SDLF/S3/AthenaBucket"
  type        = "String"
  value       = module.athena_results_bucket.id
  description = "Name of the Athena results S3 Bucket"
  overwrite   = true
}

resource "aws_ssm_parameter" "routing_queue" {
  name        = "/SDLF/SQS/QueueRouting"
  type        = "String"
  value       = aws_sqs_queue.routing.id
  description = "URL of routing queue"
  overwrite   = true
}

resource "aws_ssm_parameter" "deadletter_routing_queue" {
  name        = "/SDLF/SQS/DeadLetterQueueRouting"
  type        = "String"
  value       = aws_sqs_queue.routing_deadletter.id
  description = "URL of dead letter routing queue"
  overwrite   = true
}
