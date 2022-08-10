# Description: "Contains all the resources necessary for a single dataset"

# lookups
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ssm_parameter" "kms_infra_key" {
  name = "/SDLF/KMS/${var.team_name}/InfraKeyId"
}

data "aws_ssm_parameter" "crawler_role_arn" {
  name = "/SDLF/IAM/${var.team_name}/CrawlerRoleArn"
}

data "aws_ssm_parameter" "stage_bucket" {
  count = var.stage_bucket == null ? 1 : 0
  name  = "/SDLF/S3/StageBucket"
}

data "aws_ssm_parameter" "pipeline_bucket" {
  count = var.pipeline_bucket == null ? 1 : 0
  name  = "/SDLF/S3/ArtifactsBucket"
}

data "aws_ssm_parameter" "organization" {
  count = var.organization == null ? 1 : 0
  name  = "/SDLF/Misc/Org"
}

data "aws_ssm_parameter" "environment" {
  count = var.environment == null ? 1 : 0
  name  = "/SDLF/Misc/Env"
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

locals {
  analytics_bucket = var.analytics_bucket == null ? data.aws_ssm_parameter.analytics_bucket[0].value : var.analytics_bucket
  application_name = var.application_name == null ? data.aws_ssm_parameter.application_name[0].value : var.application_name
  central_bucket   = var.central_bucket == null ? data.aws_ssm_parameter.central_bucket[0].value : var.central_bucket
  environment      = var.environment == null ? data.aws_ssm_parameter.environment[0].value : var.environment
  organization     = var.organization == null ? data.aws_ssm_parameter.organization[0].value : var.organization
  pipeline_bucket  = var.pipeline_bucket == null ? data.aws_ssm_parameter.pipeline_bucket[0].value : var.pipeline_bucket
  stage_bucket     = var.stage_bucket == null ? data.aws_ssm_parameter.stage_bucket[0].value : var.stage_bucket
  kms_infra_key_id = data.aws_ssm_parameter.kms_infra_key.value
  crawler_role_arn = data.aws_ssm_parameter.crawler_role_arn.value
}

######## SQS #########
resource "aws_sqs_queue" "routing_post_step" {
  name                       = join("-", ["sdlf", var.team_name, var.dataset_name, "queue-b.fifo"])
  visibility_timeout_seconds = 60
  fifo_queue                 = true
  kms_master_key_id          = local.kms_infra_key_id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.routing_post_step_deadletter.arn
    maxReceiveCount     = 1
  })
}

resource "aws_sqs_queue" "routing_post_step_deadletter" {
  name                       = join("-", ["sdlf", var.team_name, var.dataset_name, "dlq-b.fifo"])
  visibility_timeout_seconds = 60
  fifo_queue                 = true
  message_retention_seconds  = 1209600
  kms_master_key_id          = local.kms_infra_key_id
}


######## TRIGGERS #########
resource "aws_cloudwatch_event_rule" "post_state" {
  name                = join("-", ["sdlf", var.team_name, var.dataset_name, "rule-b"])
  description         = "Trigger StageB Routing Lambda every 5 minutes"
  schedule_expression = "cron(*/5 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "post_state" {
  rule      = aws_cloudwatch_event_rule.post_state.name
  target_id = join("-", ["sdlf", var.team_name, var.dataset_name, "rule-b"])
  arn       = join(":", ["arn:aws:lambda", data.aws_region.current.name, data.aws_caller_identity.current.account_id, "function", join("-", ["sdlf", var.team_name, var.pipeline_name, "routing-b"])])
  input = jsonencode(
    {
      "team" : var.team_name,
      "pipeline" : var.pipeline_name,
      "pipeline_stage" : "StageB",
      "dataset" : var.dataset_name,
      "org" : local.organization,
      "app" : local.application_name,
      "env" : local.environment
    }
  )
}

resource "aws_lambda_permission" "invoke_routing" {
  action        = "lambda:InvokeFunction"
  function_name = join("-", ["sdlf", var.team_name, var.pipeline_name, "routing-b"])
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.post_state.arn
}


######## GLUE #########
resource "aws_glue_catalog_database" "this" {
  name        = join("_", [local.organization, local.application_name, local.environment, var.team_name, var.dataset_name, "db"])
  description = "${var.team_name} team ${var.dataset_name} metadata catalog"
  catalog_id  = data.aws_caller_identity.current.account_id
}

resource "aws_glue_crawler" "this" {
  database_name = aws_glue_catalog_database.this.name
  name          = "sdlf-${var.team_name}-${var.dataset_name}-post-stage-crawler"
  role          = local.crawler_role_arn

  s3_target {
    path = "s3://${local.stage_bucket}/post-stage/${var.team_name}/${var.dataset_name}"
  }
}

resource "aws_lakeformation_permissions" "crawler" {
  principal   = local.crawler_role_arn
  permissions = ["CREATE_TABLE", "ALTER", "DROP"]

  database {
    name = aws_glue_catalog_database.this.name
  }

  lifecycle {
    ignore_changes = [permissions]
  }
}

######## SSM #########
resource "aws_ssm_parameter" "queue_routing_post_step" {
  name        = "/SDLF/SQS/${var.team_name}/${var.dataset_name}StageBQueue"
  type        = "String"
  value       = split(":", aws_sqs_queue.routing_post_step.arn)[5]
  description = "Name of the StageB ${var.team_name} ${var.dataset_name} Queue"
}
resource "aws_ssm_parameter" "dlq_queue_routing_post_step" {
  name        = "/SDLF/SQS/${var.team_name}/${var.dataset_name}StageBDLQ"
  type        = "String"
  value       = split(":", aws_sqs_queue.routing_post_step_deadletter.arn)[5]
  description = "Name of the StageB ${var.team_name} ${var.dataset_name} DLQ"
}

resource "aws_ssm_parameter" "glue_data_catalog_ssm" {
  name        = "/SDLF/Glue/${var.team_name}/${var.dataset_name}/DataCatalog"
  type        = "String"
  value       = aws_glue_catalog_database.this.id
  description = "${var.team_name} team ${var.dataset_name} metadata catalog"
}

######### Octagon Entry ###########
data "aws_dynamodb_table" "octagon" {
  name = "octagon-Datasets-${local.environment}"
}

resource "aws_dynamodb_table_item" "octagon" {
  table_name = data.aws_dynamodb_table.octagon.name
  hash_key   = data.aws_dynamodb_table.octagon.hash_key

  item = <<ITEM
{
  "name": {
    "S": "${var.team_name}-${var.dataset_name}"
  },
  "pipeline": {
    "S": "${var.pipeline_name}"
  },
  "transforms": {
    "M": {
      "stage_a_transform": {
        "S": "${var.stage_a_transform_name}"
      },
      "stage_b_transform": {
        "S": "${var.stage_b_transform_name}"
      }
    }
  },
  "max_items_process": {
    "M": {
      "stage_b": {
        "N": "100"
      },
      "stage_c": {
        "N": "100"
      }
    }
  },
  "min_items_process": {
    "M": {
     "stage_b": {
       "N": "1"
     },
     "stage_c": {
       "N": "1"
      }
    }
  },
  "version": {
     "N": "1"
  }
}
ITEM

  lifecycle {
    ignore_changes = [item]
  }
}
