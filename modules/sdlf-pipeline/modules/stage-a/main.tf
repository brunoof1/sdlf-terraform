# description = "Contains StageA StateMachine Definition"

# lookups
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_kms_key" "infra" {
  key_id = var.kms_infra_key_id
}
data "aws_kms_key" "data" {
  key_id = var.kms_data_key_id
}

locals {
  lambda_runtime = "python3.7"
  lambda_handler = "lambda_function.lambda_handler"
  lambda_layers  = [var.datalake_library_layer_arn]
}

######## SQS #########
resource "aws_sqs_queue" "routing_step" {
  name                       = join("-", ["sdlf", var.team_name, var.pipeline_name, "queue-a.fifo"])
  visibility_timeout_seconds = 60
  fifo_queue                 = true
  kms_master_key_id          = var.kms_infra_key_id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.routing_step_deadletter.arn
    maxReceiveCount     = 1
  })
}

resource "aws_sqs_queue" "routing_step_deadletter" {
  name                       = join("-", ["sdlf", var.team_name, var.pipeline_name, "dlq-a.fifo"])
  visibility_timeout_seconds = 60
  message_retention_seconds  = 1209600
  fifo_queue                 = true
  kms_master_key_id          = var.kms_infra_key_id
}

resource "aws_lambda_event_source_mapping" "routing_step" {
  event_source_arn = aws_sqs_queue.routing_step.arn
  function_name    = aws_lambda_function.routing.arn
}

######## IAM #########
resource "aws_iam_policy" "lambda_common" {
  name   = "sdlf-${var.team_name}-${var.pipeline_name}-common-a"
  policy = data.aws_iam_policy_document.lambda_common.json
}

data "aws_iam_policy_document" "lambda_common" {

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
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/SDLF/*"
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
      data.aws_kms_key.infra.arn
    ]
  }
}

resource "aws_iam_role" "routing" {
  name                 = "sdlf-${var.team_name}-${var.pipeline_name}-routing-a"
  permissions_boundary = var.permissions_boundary_managed_policy
  path                 = "/state-machine/"
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "routing" {
  role       = aws_iam_role.routing.name
  policy_arn = aws_iam_policy.lambda_common.arn
}

resource "aws_iam_role_policy" "routing" {
  name   = "sdlf-${var.team_name}-${var.pipeline_name}-routing-a"
  role   = aws_iam_role.routing.id
  policy = data.aws_iam_policy_document.routing.json
}

data "aws_iam_policy_document" "routing" {
  statement {
    actions = [
      "states:StartExecution"
    ]
    resources = [
      aws_sfn_state_machine.this.arn
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
      aws_sqs_queue.routing_step.arn,
      aws_sqs_queue.routing_step_deadletter.arn
    ]
  }
}

resource "aws_iam_role" "step1" {
  name                 = "sdlf-${var.team_name}-${var.pipeline_name}-preupdate-a"
  permissions_boundary = var.permissions_boundary_managed_policy
  path                 = "/state-machine/"
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "step1" {
  role       = aws_iam_role.step1.name
  policy_arn = aws_iam_policy.lambda_common.arn
}

resource "aws_iam_role_policy" "step1" {
  name   = "sdlf-${var.team_name}-${var.pipeline_name}-preupdate-a"
  role   = aws_iam_role.step1.id
  policy = data.aws_iam_policy_document.step1.json
}

data "aws_iam_policy_document" "step1" {
  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.stage_bucket}"
    ]
  }

  statement {
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::${var.stage_bucket}/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/stage/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/pre-stage/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/post-stage/${var.team_name}/*"
    ]
  }
}

resource "aws_iam_role" "step2" {
  name                 = "sdlf-${var.team_name}-${var.pipeline_name}-process-a"
  permissions_boundary = var.permissions_boundary_managed_policy
  path                 = "/state-machine/"
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "step2" {
  role       = aws_iam_role.step2.name
  policy_arn = aws_iam_policy.lambda_common.arn
}

resource "aws_iam_role_policy" "step2" {
  name   = "sdlf-${var.team_name}-${var.pipeline_name}-process-a"
  role   = aws_iam_role.step2.id
  policy = data.aws_iam_policy_document.step2.json
}

data "aws_iam_policy_document" "step2" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning"
    ]
    resources = [
      "arn:aws:s3:::${var.dataset_bucket}",
      "arn:aws:s3:::${var.raw_bucket}",
      "arn:aws:s3:::${var.stage_bucket}",
      "arn:aws:s3:::${var.artifacts_bucket}"
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${var.raw_bucket}/${var.team_name}/*",
      "arn:aws:s3:::${var.raw_bucket}/raw/${var.team_name}/*",
      "arn:aws:s3:::${var.dataset_bucket}/${var.team_name}/*",
      "arn:aws:s3:::${var.dataset_bucket}/raw/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/stage/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/pre-stage/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/post-stage/${var.team_name}/*"
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
      data.aws_kms_key.data.arn
    ]
  }
}

resource "aws_iam_role" "step3" {
  name                 = "sdlf-${var.team_name}-${var.pipeline_name}-postupdate-a"
  permissions_boundary = var.permissions_boundary_managed_policy
  path                 = "/state-machine/"
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "step3" {
  role       = aws_iam_role.step3.name
  policy_arn = aws_iam_policy.lambda_common.arn
}

resource "aws_iam_role_policy" "step3" {
  name   = "sdlf-${var.team_name}-${var.pipeline_name}-postupdate-a"
  role   = aws_iam_role.step3.id
  policy = data.aws_iam_policy_document.step3.json
}

data "aws_iam_policy_document" "step3" {
  statement {
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueues",
      "sqs:ListDeadLetterSourceQueues",
      "sqs:ListQueueTags",
      "sqs:SendMessage",
      "sqs:SendMessageBatch"
    ]
    resources = [
      "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.stage_bucket}"
    ]
  }

  statement {
    actions = [
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:::${var.stage_bucket}/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/stage/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/pre-stage/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/post-stage/${var.team_name}/*"
    ]
  }
}

# Error Handling Lambda Role
resource "aws_iam_role" "error_step" {
  name                 = "sdlf-${var.team_name}-${var.pipeline_name}-error-a"
  permissions_boundary = var.permissions_boundary_managed_policy
  path                 = "/state-machine/"
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "error_step" {
  role       = aws_iam_role.error_step.name
  policy_arn = aws_iam_policy.lambda_common.arn
}

resource "aws_iam_role_policy" "error_step" {
  name   = "sdlf-${var.team_name}-${var.pipeline_name}-error-a"
  role   = aws_iam_role.error_step.id
  policy = data.aws_iam_policy_document.error_step.json
}

data "aws_iam_policy_document" "error_step" {
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
      aws_sqs_queue.routing_step_deadletter.arn
    ]
  }
}

######## LAMBDA FUNCTIONS #########

data "archive_file" "routing" {
  type        = "zip"
  source_file = "${path.module}/lambda/stage-a-routing/src/lambda_function.py"
  output_path = "${path.module}/lambda/stage-a-routing/stage-a-routing.zip"
}

resource "aws_lambda_function" "routing" {
  function_name    = join("-", ["sdlf", var.team_name, var.pipeline_name, "routing-a"])
  description      = "Routes S3 PutObject Logs to the relevant StageA State Machine"
  role             = aws_iam_role.routing.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 256
  timeout          = 60
  source_code_hash = data.archive_file.routing.output_base64sha256
  filename         = data.archive_file.routing.output_path
  layers           = [var.datalake_library_layer_arn]
}

data "archive_file" "redrive" {
  type        = "zip"
  source_file = "${path.module}/lambda/stage-a-redrive/src/lambda_function.py"
  output_path = "${path.module}/lambda/stage-a-redrive/stage-a-redrive.zip"
}

resource "aws_lambda_function" "redrive" {
  function_name    = join("-", ["sdlf", var.team_name, var.pipeline_name, "redrive-a"])
  description      = "Redrives Failed S3 PutObject Logs to the routing queue"
  role             = aws_iam_role.routing.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 256
  timeout          = 300
  source_code_hash = data.archive_file.redrive.output_base64sha256
  filename         = data.archive_file.redrive.output_path
  layers           = [var.datalake_library_layer_arn]

  environment {
    variables = {
      TEAM     = var.team_name,
      PIPELINE = var.pipeline_name,
      STAGE    = "StageA"
    }
  }
}

data "archive_file" "preupdate" {
  type        = "zip"
  source_file = "${path.module}/lambda/stage-a-preupdate-metadata/src/lambda_function.py"
  output_path = "${path.module}/lambda/stage-a-preupdate-metadata/stage-a-preupdate-metadata.zip"
}

resource "aws_lambda_function" "preupdate" {
  function_name    = join("-", ["sdlf", var.team_name, var.pipeline_name, "preupdate-a"])
  description      = "Pre-Update the metadata in the DynamoDB Catalog table"
  role             = aws_iam_role.step1.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 128
  timeout          = 300
  source_code_hash = data.archive_file.preupdate.output_base64sha256
  filename         = data.archive_file.preupdate.output_path
  layers           = [var.datalake_library_layer_arn]
}


data "archive_file" "process" {
  type        = "zip"
  source_file = "${path.module}/lambda/stage-a-process-object/src/lambda_function.py"
  output_path = "${path.module}/lambda/stage-a-process-object/stage-a-process-object.zip"
}

resource "aws_lambda_function" "process" {
  function_name    = join("-", ["sdlf", var.team_name, var.pipeline_name, "process-a"])
  description      = "Processing pipeline"
  role             = aws_iam_role.step2.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 1024
  timeout          = 600
  source_code_hash = data.archive_file.process.output_base64sha256
  filename         = data.archive_file.process.output_path
  layers           = [var.datalake_library_layer_arn]
}

data "archive_file" "postupdate" {
  type        = "zip"
  source_file = "${path.module}/lambda/stage-a-postupdate-metadata/src/lambda_function.py"
  output_path = "${path.module}/lambda/stage-a-postupdate-metadata/stage-a-postupdate-metadata.zip"
}

resource "aws_lambda_function" "postupdate" {
  function_name    = join("-", ["sdlf", var.team_name, var.pipeline_name, "postupdate-a"])
  description      = "Post-Update the metadata in the DynamoDB Catalog table"
  role             = aws_iam_role.step3.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 256
  timeout          = 600
  source_code_hash = data.archive_file.postupdate.output_base64sha256
  filename         = data.archive_file.postupdate.output_path
  layers           = [var.datalake_library_layer_arn]
}

data "archive_file" "error" {
  type        = "zip"
  source_file = "${path.module}/lambda/stage-a-error/src/lambda_function.py"
  output_path = "${path.module}/lambda/stage-a-error/stage-a-error.zip"
}

resource "aws_lambda_function" "error" {
  function_name    = join("-", ["sdlf", var.team_name, var.pipeline_name, "error-a"])
  description      = "Fallback lambda to handle messages which failed processing"
  role             = aws_iam_role.error_step.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 256
  timeout          = 600
  source_code_hash = data.archive_file.error.output_base64sha256
  filename         = data.archive_file.error.output_path
  layers           = [var.datalake_library_layer_arn]
}

######## CLOUDWATCH #########

resource "aws_cloudwatch_log_group" "routing" {
  name = join("", ["/aws/lambda/", reverse(split(":", aws_lambda_function.routing.arn))[0]])
}

resource "aws_cloudwatch_log_subscription_filter" "routing" {
  count           = var.elasticsearch_enabled == true ? 1 : 0
  name            = join("-", ["sdlf-log-stream", "routing"])
  log_group_name  = aws_cloudwatch_log_group.routing.name
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = var.kibana_function_arn
}

resource "aws_cloudwatch_metric_alarm" "routing" {
  alarm_name          = join("-", ["sdlf", var.team_name, var.pipeline_name, "routing-a"])
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "5"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  unit                = "Count"
  alarm_description   = "StageA ${var.team_name} ${var.pipeline_name} Routing Lambda Alarm"
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    Name  = "FunctionName"
    Value = reverse(split(":", aws_lambda_function.routing.arn))[0]
  }
}

resource "aws_cloudwatch_log_group" "redrive" {
  name = join("", ["/aws/lambda/", reverse(split(":", aws_lambda_function.redrive.arn))[0]])
}

resource "aws_cloudwatch_log_subscription_filter" "redrive" {
  count           = var.elasticsearch_enabled == true ? 1 : 0
  name            = join("-", ["sdlf-log-stream", "redrive"])
  log_group_name  = aws_cloudwatch_log_group.redrive.name
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = var.kibana_function_arn
}

resource "aws_cloudwatch_log_group" "preupdate" {
  name = join("", ["/aws/lambda/", reverse(split(":", aws_lambda_function.preupdate.arn))[0]])
}

resource "aws_cloudwatch_log_subscription_filter" "preupdate" {
  count           = var.elasticsearch_enabled == true ? 1 : 0
  name            = join("-", ["sdlf-log-stream", "preupdate"])
  log_group_name  = aws_cloudwatch_log_group.preupdate.name
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = var.kibana_function_arn
}

resource "aws_cloudwatch_log_group" "process" {
  name = join("", ["/aws/lambda/", reverse(split(":", aws_lambda_function.process.arn))[0]])
}

resource "aws_cloudwatch_log_subscription_filter" "process" {
  count           = var.elasticsearch_enabled == true ? 1 : 0
  name            = join("-", ["sdlf-log-stream", "process"])
  log_group_name  = aws_cloudwatch_log_group.process.name
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = var.kibana_function_arn
}

resource "aws_cloudwatch_log_group" "postupdate" {
  name = join("", ["/aws/lambda/", reverse(split(":", aws_lambda_function.postupdate.arn))[0]])
}

resource "aws_cloudwatch_log_subscription_filter" "postupdate" {
  count           = var.elasticsearch_enabled == true ? 1 : 0
  name            = join("-", ["sdlf-log-stream", "postupdate"])
  log_group_name  = aws_cloudwatch_log_group.postupdate.name
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = var.kibana_function_arn
}

resource "aws_cloudwatch_log_group" "error" {
  name = join("", ["/aws/lambda/", reverse(split(":", aws_lambda_function.error.arn))[0]])
}

resource "aws_cloudwatch_log_subscription_filter" "error" {
  count           = var.elasticsearch_enabled == true ? 1 : 0
  name            = join("-", ["sdlf-log-stream", "error"])
  log_group_name  = aws_cloudwatch_log_group.error.name
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = var.kibana_function_arn
}

resource "aws_cloudwatch_metric_alarm" "error" {
  alarm_name          = join("-", ["sdlf", var.team_name, var.pipeline_name, "error-a"])
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "5"
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "5"
  unit                = "Count"
  alarm_description   = "StageA ${var.team_name} ${var.pipeline_name} Error Lambda Alarm"
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    Name  = "FunctionName"
    Value = reverse(split(":", aws_lambda_function.error.arn))[0]
  }
}


######## STATE MACHINE #########
resource "aws_sfn_state_machine" "this" {
  name       = join("-", ["sdlf", var.team_name, var.pipeline_name, "sm-a"])
  role_arn   = var.states_execution_role_arn
  definition = data.template_file.sfn_definition.rendered
}

data "template_file" "sfn_definition" {
  template = file("${path.module}/statemachines/this.json")

  vars = {
    preupdate_lambda_arn  = aws_lambda_function.preupdate.arn
    process_lambda_arn    = aws_lambda_function.process.arn
    postupdate_lambda_arn = aws_lambda_function.postupdate.arn
    error_lambda_arn      = aws_lambda_function.error.arn
  }
}


######## SSM OUTPUTS #########
resource "aws_ssm_parameter" "routing_queue" {
  name        = "/SDLF/SQS/${var.team_name}/${var.pipeline_name}StageAQueue"
  type        = "String"
  value       = split(":", aws_sqs_queue.routing_step.arn)[5]
  description = "Name of the StageA ${var.team_name} ${var.pipeline_name} Queue"
}

resource "aws_ssm_parameter" "routing_deadletter_queue" {
  name        = "/SDLF/SQS/${var.team_name}/${var.pipeline_name}StageADLQ"
  type        = "String"
  value       = split(":", aws_sqs_queue.routing_step_deadletter.arn)[5]
  description = "Name of the StageA ${var.team_name} ${var.pipeline_name} DLQ"
}

resource "aws_ssm_parameter" "statemachine" {
  name        = "/SDLF/SM/${var.team_name}/${var.pipeline_name}StageASM"
  type        = "String"
  value       = aws_sfn_state_machine.this.arn
  description = "ARN of the StageA ${var.team_name} ${var.pipeline_name} State Machine"
}

######### Octagon Entry ###########
data "aws_dynamodb_table" "octagon" {
  name = "octagon-Pipelines-${var.environment}"
}

resource "aws_dynamodb_table_item" "octagon" {
  table_name = data.aws_dynamodb_table.octagon.name
  hash_key   = data.aws_dynamodb_table.octagon.hash_key

  item = <<ITEM
{
  "name": {
    "S": "${var.team_name}-${var.pipeline_name}-stage-a"
  },
  "type": {
    "S": "TRANSFORMATION"
  },
  "status": {
    "S": "ACTIVE"
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
