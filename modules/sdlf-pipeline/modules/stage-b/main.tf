# Description: "Contains StageB StateMachine Definition"

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
  lambda_runtime             = "python3.7"
  lambda_handler             = "lambda_function.lambda_handler"
  data_quality_state_machine = var.data_quality_state_machine == null ? data.aws_ssm_parameter.data_quality_state_machine[0].value : var.data_quality_state_machine
  lambda_layers              = [var.datalake_library_layer_arn]
}

######## IAM #########
resource "aws_iam_policy" "lambda_common" {
  name   = "sdlf-${var.team_name}-${var.pipeline_name}-common-b"
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
  name                 = "sdlf-${var.team_name}-${var.pipeline_name}-routing-b"
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
  name   = "sdlf-${var.team_name}-${var.pipeline_name}-routing-b"
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
      "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-${var.team_name}-*"
    ]
  }
}

resource "aws_iam_role" "step1" {
  name                 = "sdlf-${var.team_name}-${var.pipeline_name}-process-b"
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
  name   = "sdlf-${var.team_name}-${var.pipeline_name}-process-b"
  role   = aws_iam_role.step1.id
  policy = data.aws_iam_policy_document.step1.json
}

data "aws_iam_policy_document" "step1" {
  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.dataset_bucket}"
    ]
  }

  statement {
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::${var.dataset_bucket}/${var.team_name}/*",
      "arn:aws:s3:::${var.dataset_bucket}/stage/${var.team_name}/*",
      "arn:aws:s3:::${var.dataset_bucket}/pre-stage/${var.team_name}/*",
      "arn:aws:s3:::${var.dataset_bucket}/post-stage/${var.team_name}/*",
      "arn:aws:s3:::${var.dataset_bucket}/analytics/${var.team_name}/*"
    ]
  }

  statement {
    actions = [
      "glue:GetJobRun",
      "glue:GetJobRuns",
      "glue:StartJobRun"
    ]
    resources = [
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:job/sdlf-${var.team_name}-*"
    ]
  }
}

# Step2 Role
resource "aws_iam_role" "step2" {
  name                 = "sdlf-${var.team_name}-${var.pipeline_name}-crawl-b"
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
  name   = "sdlf-${var.team_name}-${var.pipeline_name}-crawl-b"
  role   = aws_iam_role.step2.id
  policy = data.aws_iam_policy_document.step2.json
}

data "aws_iam_policy_document" "step2" {
  statement {
    actions = [
      "glue:StartCrawler"
    ]
    resources = [
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:crawler/sdlf-${var.team_name}-*"
    ]
  }
}

# Step3 Role
resource "aws_iam_role" "step3" {
  name                 = "sdlf-${var.team_name}-${var.pipeline_name}-postupdate-b"
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
  name   = "sdlf-${var.team_name}-${var.pipeline_name}-postupdate-b"
  role   = aws_iam_role.step3.id
  policy = data.aws_iam_policy_document.step3.json
}

data "aws_iam_policy_document" "step3" {

  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.dataset_bucket}"
    ]
  }

  statement {
    actions = [
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:::${var.dataset_bucket}/${var.team_name}/*",
      "arn:aws:s3:::${var.dataset_bucket}/stage/${var.team_name}/*",
      "arn:aws:s3:::${var.dataset_bucket}/pre-stage/${var.team_name}/*",
      "arn:aws:s3:::${var.dataset_bucket}/post-stage/${var.team_name}/*",
      "arn:aws:s3:::${var.dataset_bucket}/analytics/${var.team_name}/*"
    ]
  }
}

# Error Handling Lambda Role

resource "aws_iam_role" "error_step" {
  name                 = "sdlf-${var.team_name}-${var.pipeline_name}-error-b"
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
  name   = "sdlf-${var.team_name}-${var.pipeline_name}-error-b"
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
      "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-${var.team_name}-*"
    ]
  }
}

######## LAMBDA FUNCTIONS #########
data "archive_file" "routing" {
  type        = "zip"
  source_file = "${path.module}/lambda/stage-b-routing/src/lambda_function.py"
  output_path = "${path.module}/lambda/stage-b-routing/stage-b-routing.zip"
}

resource "aws_lambda_function" "routing" {
  function_name    = join("-", ["sdlf", var.team_name, var.pipeline_name, "routing-b"])
  description      = "Checks if items are to be processed and route them to state machine"
  role             = aws_iam_role.routing.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 256
  timeout          = 300
  source_code_hash = data.archive_file.routing.output_base64sha256
  filename         = data.archive_file.routing.output_path
  layers           = [var.datalake_library_layer_arn]
}

data "archive_file" "redrive" {
  type        = "zip"
  source_file = "${path.module}/lambda/stage-b-redrive/src/lambda_function.py"
  output_path = "${path.module}/lambda/stage-b-redrive/stage-b-redrive.zip"
}

resource "aws_lambda_function" "redrive" {
  function_name    = join("-", ["sdlf", var.team_name, var.pipeline_name, "redrive-b"])
  description      = "Redrives Failed messages to the routing queue"
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
      STAGE    = "StageB"
    }
  }
}


data "archive_file" "process" {
  type        = "zip"
  source_file = "${path.module}/lambda/stage-b-process-data/src/lambda_function.py"
  output_path = "${path.module}/lambda/stage-b-process-data/stage-b-process-data.zip"
}

resource "aws_lambda_function" "process" {
  function_name    = join("-", ["sdlf", var.team_name, var.pipeline_name, "preupdate-b"])
  description      = "Processing pipeline"
  role             = aws_iam_role.step1.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 1024
  timeout          = 900
  source_code_hash = data.archive_file.process.output_base64sha256
  filename         = data.archive_file.process.output_path
  layers           = [var.datalake_library_layer_arn]
}

data "archive_file" "checkjob" {
  type        = "zip"
  source_file = "${path.module}/lambda/stage-b-check-job/src/lambda_function.py"
  output_path = "${path.module}/lambda/stage-b-check-job/stage-b-check-job.zip"
}

resource "aws_lambda_function" "checkjob" {
  function_name    = join("-", ["sdlf", var.team_name, var.pipeline_name, "checkjob-b"])
  description      = "Checks if job has finished (success/failure)"
  role             = aws_iam_role.step1.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 256
  timeout          = 300
  source_code_hash = data.archive_file.checkjob.output_base64sha256
  filename         = data.archive_file.checkjob.output_path
  layers           = [var.datalake_library_layer_arn]
}

data "archive_file" "crawl_data" {
  type        = "zip"
  source_file = "${path.module}/lambda/stage-b-crawl-data/src/lambda_function.py"
  output_path = "${path.module}/lambda/stage-b-crawl-data/stage-b-crawl-data.zip"
}

resource "aws_lambda_function" "crawl_data" {
  function_name    = join("-", ["sdlf", var.team_name, var.pipeline_name, "crawl-b"])
  description      = "Glue crawler"
  role             = aws_iam_role.step2.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 512
  timeout          = 300
  source_code_hash = data.archive_file.crawl_data.output_base64sha256
  filename         = data.archive_file.crawl_data.output_path
  layers           = [var.datalake_library_layer_arn]
}

data "archive_file" "postupdate" {
  type        = "zip"
  source_file = "${path.module}/lambda/stage-b-postupdate-metadata/src/lambda_function.py"
  output_path = "${path.module}/lambda/stage-b-postupdate-metadata/stage-b-postupdate-metadata.zip"
}

resource "aws_lambda_function" "postupdate" {
  function_name    = join("-", ["sdlf", var.team_name, var.pipeline_name, "postupdate-b"])
  description      = "Post-Update the metadata in the DynamoDB Catalog table"
  role             = aws_iam_role.step3.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 512
  timeout          = 600
  source_code_hash = data.archive_file.postupdate.output_base64sha256
  filename         = data.archive_file.postupdate.output_path
  layers           = [var.datalake_library_layer_arn]
}

data "archive_file" "error" {
  type        = "zip"
  source_file = "${path.module}/lambda/stage-b-error/src/lambda_function.py"
  output_path = "${path.module}/lambda/stage-b-error/stage-b-error.zip"
}

resource "aws_lambda_function" "error" {
  function_name    = join("-", ["sdlf", var.team_name, var.pipeline_name, "error-b"])
  description      = "Fallback lambda to handle messages which failed processing"
  role             = aws_iam_role.error_step.arn
  handler          = local.lambda_handler
  runtime          = local.lambda_runtime
  memory_size      = 256
  timeout          = 300
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
  name            = join("-", ["sdlf-log-stream", "routing-b"])
  log_group_name  = aws_cloudwatch_log_group.routing.name
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = var.kibana_function_arn
}

resource "aws_cloudwatch_metric_alarm" "routing" {
  alarm_name          = join("-", ["sdlf", var.team_name, var.pipeline_name, "routing-b"])
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "5"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  unit                = "Count"
  alarm_description   = "StageB ${var.team_name} ${var.pipeline_name} Routing Lambda Alarm"
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
  name            = join("-", ["sdlf-log-stream", "redrive-b"])
  log_group_name  = aws_cloudwatch_log_group.redrive.name
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = var.kibana_function_arn
}

resource "aws_cloudwatch_log_group" "process" {
  name = join("", ["/aws/lambda/", reverse(split(":", aws_lambda_function.process.arn))[0]])
}

resource "aws_cloudwatch_log_subscription_filter" "process" {
  count           = var.elasticsearch_enabled == true ? 1 : 0
  name            = join("-", ["sdlf-log-stream", "process-b"])
  log_group_name  = aws_cloudwatch_log_group.process.name
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = var.kibana_function_arn
}

resource "aws_cloudwatch_log_group" "checkjob" {
  name = join("", ["/aws/lambda/", reverse(split(":", aws_lambda_function.checkjob.arn))[0]])
}

resource "aws_cloudwatch_log_subscription_filter" "checkjob" {
  count           = var.elasticsearch_enabled == true ? 1 : 0
  name            = join("-", ["sdlf-log-stream", "checkjob-b"])
  log_group_name  = aws_cloudwatch_log_group.checkjob.name
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = var.kibana_function_arn
}

resource "aws_cloudwatch_log_group" "crawl_data" {
  name = join("", ["/aws/lambda/", reverse(split(":", aws_lambda_function.crawl_data.arn))[0]])
}

resource "aws_cloudwatch_log_subscription_filter" "crawl_data" {
  count           = var.elasticsearch_enabled == true ? 1 : 0
  name            = join("-", ["sdlf-log-stream", "crawl-data-b"])
  log_group_name  = aws_cloudwatch_log_group.crawl_data.name
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = var.kibana_function_arn
}

resource "aws_cloudwatch_log_group" "postupdate" {
  name = join("", ["/aws/lambda/", reverse(split(":", aws_lambda_function.postupdate.arn))[0]])
}

resource "aws_cloudwatch_log_subscription_filter" "postupdate" {
  count           = var.elasticsearch_enabled == true ? 1 : 0
  name            = join("-", ["sdlf-log-stream", "postupdate-b"])
  log_group_name  = aws_cloudwatch_log_group.postupdate.name
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = var.kibana_function_arn
}

resource "aws_cloudwatch_log_group" "error" {
  name = join("", ["/aws/lambda/", reverse(split(":", aws_lambda_function.error.arn))[0]])
}

resource "aws_cloudwatch_log_subscription_filter" "error" {
  count           = var.elasticsearch_enabled == true ? 1 : 0
  name            = join("-", ["sdlf-log-stream", "error-b"])
  log_group_name  = aws_cloudwatch_log_group.error.name
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = var.kibana_function_arn
}

resource "aws_cloudwatch_metric_alarm" "error" {
  alarm_name          = join("-", ["sdlf", var.team_name, var.pipeline_name, "error-b"])
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "5"
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  unit                = "Count"
  alarm_description   = "StageB ${var.team_name} ${var.pipeline_name} Error Lambda Alarm"
  alarm_actions       = [var.sns_topic_arn]
  dimensions = {
    Name  = "FunctionName"
    Value = reverse(split(":", aws_lambda_function.error.arn))[0]
  }
}


######## STATE MACHINE #########
resource "aws_sfn_state_machine" "this" {
  name       = join("-", ["sdlf", var.team_name, var.pipeline_name, "sm-b"])
  role_arn   = var.states_execution_role_arn
  definition = data.template_file.sfn_definition.rendered
}

data "template_file" "sfn_definition" {
  template = file("${path.module}/statemachines/this.json")

  vars = {
    process_lambda_arn         = aws_lambda_function.process.arn
    checkjob_lambda_arn        = aws_lambda_function.checkjob.arn
    crawl_data_lambda_arn      = aws_lambda_function.crawl_data.arn
    postupdate_lambda_arn      = aws_lambda_function.postupdate.arn
    error_lambda_arn           = aws_lambda_function.error.arn
    data_quality_state_machine = local.data_quality_state_machine
  }
}

######## SSM OUTPUTS #########
resource "aws_ssm_parameter" "statemachine" {
  name        = "/SDLF/SM/${var.team_name}/${var.pipeline_name}StageBSM"
  type        = "String"
  value       = aws_sfn_state_machine.this.arn
  description = "ARN of the StageB ${var.team_name} ${var.pipeline_name} State Machine"
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
    "S": "${var.team_name}-${var.pipeline_name}-stage-b"
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
