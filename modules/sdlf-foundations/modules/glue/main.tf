# Description: Data Quality And Glue Catalog Tables Schema Replication

# lookups
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_kms_key" "this" {
  key_id = var.kms_key_id
}

locals {
  kms_key_arn            = data.aws_kms_key.this.arn
  glue_scripts_directory = "deequ"
  glue_scripts = {
    "jar"                 = "deequ-1.0.3-RC1.jar",
    "analysis"            = "deequ-analysis-verification-runner.scala",
    "controller"          = "deequ-controller.py",
    "profile"             = "deequ-profile-runner.scala",
    "suggestion-analysis" = "deequ-suggestion-analysis-verification-runner.scala"
  }
}

resource "aws_iam_policy" "common" {
  name   = "sdlf-data-quality-common"
  path   = "/"
  policy = data.aws_iam_policy_document.common.json
}

data "aws_iam_policy_document" "common" {
  statement {
    actions = [
      "logs:CreateLogGroup"
    ]

    resources = [
      join(":", ["arn:aws:logs", data.aws_region.current.name, data.aws_caller_identity.current.account_id, "*"])
    ]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:AssociateKmsKey"
    ]

    resources = [
      join(":", ["arn:aws:logs", data.aws_region.current.name, data.aws_caller_identity.current.account_id, "log-group", "/aws/lambda/sdlf-*"])
    ]
  }

  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]

    resources = [
      join(":", ["arn:aws:ssm", data.aws_region.current.name, data.aws_caller_identity.current.account_id, "parameter/SDLF/*"])
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
      join(":", ["arn:aws:dynamodb", data.aws_region.current.name, data.aws_caller_identity.current.account_id, "table/octagon-*"])
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

resource "aws_iam_role" "lambda_step1" {
  name               = "sdlf-data-quality-initial-check"
  path               = "/state-machine/"
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

resource "aws_iam_role_policy_attachment" "lambda_step1" {
  role       = aws_iam_role.lambda_step1.name
  policy_arn = aws_iam_policy.common.arn
}

resource "aws_iam_role_policy" "lambda_step1" {
  name = "sdlf-data-quality-initial-check"
  role = aws_iam_role.lambda_step1.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "glue:GetJobRun",
          "glue:StartJobRun"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role" "lambda_step2" {
  name               = "sdlf-data-quality-crawl"
  path               = "/state-machine/"
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

resource "aws_iam_role_policy_attachment" "lambda_step2" {
  role       = aws_iam_role.lambda_step2.name
  policy_arn = aws_iam_policy.common.arn
}

resource "aws_iam_role_policy" "lambda_step2" {
  name = "sdlf-data-quality-crawl"
  role = aws_iam_role.lambda_step2.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "glue:StartCrawler"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role" "states_execution" {
  name               = "sdlf-data-quality-states-execution"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "states.${data.aws_region.current.name}.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "states_execution" {
  name = "sdlf-data-quality-states-execution"
  role = aws_iam_role.states_execution.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "lambda:InvokeFunction"
        ],
        "Effect": "Allow",
        "Resource": [
          "${aws_lambda_function.step1.arn}",
          "${aws_lambda_function.step2.arn}",
          "${aws_lambda_function.job_check_step.arn}"
        ]
      }
    ]
  }
  EOF
}

data "archive_file" "step1" {
  type        = "zip"
  source_file = "${path.module}/lambda/initial-check/src/lambda_function.py"
  output_path = "${path.module}/lambda/initial-check/initial-check.zip"
}

resource "aws_lambda_function" "step1" {
  function_name    = "sdlf-data-quality-initial-check"
  description      = "Performs checks and determines which Data Quality job to run"
  role             = aws_iam_role.lambda_step1.arn
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  memory_size      = 256
  timeout          = 300
  source_code_hash = data.archive_file.step1.output_base64sha256
  filename         = data.archive_file.step1.output_path
  dynamic "tracing_config" {
    for_each = var.lambda_tracing_config_mode == null ? [] : [1]
    content {
      mode = var.lambda_tracing_config_mode
    }
  }
}

resource "aws_cloudwatch_log_group" "step1" {
  name              = join("/", ["/aws", "lambda", "sdlf-data-quality-initial-check"])
  kms_key_id        = data.aws_kms_key.this.arn
  retention_in_days = var.lambda_log_retention
}

data "archive_file" "job_check_step" {
  type        = "zip"
  source_file = "${path.module}/lambda/check-job/src/lambda_function.py"
  output_path = "${path.module}/lambda/check-job/check-job.zip"
}

resource "aws_lambda_function" "job_check_step" {
  function_name    = "sdlf-data-quality-check-job"
  description      = "Checks if job has finished (success/failure)"
  role             = aws_iam_role.lambda_step1.arn
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  memory_size      = 256
  timeout          = 300
  source_code_hash = data.archive_file.job_check_step.output_base64sha256
  filename         = data.archive_file.job_check_step.output_path
  dynamic "tracing_config" {
    for_each = var.lambda_tracing_config_mode == null ? [] : [1]
    content {
      mode = var.lambda_tracing_config_mode
    }
  }
}

resource "aws_cloudwatch_log_group" "job_check_step" {
  name              = join("/", ["/aws", "lambda", "sdlf-data-quality-check-job"])
  kms_key_id        = data.aws_kms_key.this.arn
  retention_in_days = var.lambda_log_retention
}

data "archive_file" "step2" {
  type        = "zip"
  source_file = "${path.module}/lambda/crawl-data/src/lambda_function.py"
  output_path = "${path.module}/lambda/crawl-data/crawl-data.zip"
}

resource "aws_lambda_function" "step2" {
  function_name    = "sdlf-data-quality-crawl-data"
  description      = "Glue Crawler"
  role             = aws_iam_role.lambda_step2.arn
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  memory_size      = 256
  timeout          = 120
  source_code_hash = data.archive_file.step2.output_base64sha256
  filename         = data.archive_file.step2.output_path
  dynamic "tracing_config" {
    for_each = var.lambda_tracing_config_mode == null ? [] : [1]
    content {
      mode = var.lambda_tracing_config_mode
    }
  }
}

resource "aws_cloudwatch_log_group" "step2" {
  name              = join("/", ["/aws", "lambda", "sdlf-data-quality-crawl-data"])
  kms_key_id        = data.aws_kms_key.this.arn
  retention_in_days = var.lambda_log_retention
}

data "archive_file" "replicate" {
  type        = "zip"
  source_file = "${path.module}/lambda/replicate/src/lambda_function.py"
  output_path = "${path.module}/lambda/replicate/replicate.zip"
}

resource "aws_lambda_function" "replicate" {
  function_name    = "sdlf-glue-replication"
  description      = "Replicates Glue Catalog Metadata and Data Quality to Octagon Schemas Table"
  role             = var.datalake_admin_role_arn
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  memory_size      = 128
  timeout          = 300
  source_code_hash = data.archive_file.replicate.output_base64sha256
  filename         = data.archive_file.replicate.output_path
  dynamic "tracing_config" {
    for_each = var.lambda_tracing_config_mode == null ? [] : [1]
    content {
      mode = var.lambda_tracing_config_mode
    }
  }
}

resource "aws_cloudwatch_log_group" "replicate" {
  name              = join("/", ["/aws", "lambda", "sdlf-glue-replication"])
  kms_key_id        = data.aws_kms_key.this.arn
  retention_in_days = var.lambda_log_retention
}

resource "aws_lambda_permission" "events" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.replicate.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.metadata_change.arn
}

resource "aws_cloudwatch_event_rule" "metadata_change" {
  name          = "sdlf-foundations-replicate-trigger"
  description   = "Triggers Glue replicate Lambda upon change to metadata catalog"
  event_pattern = <<EOF
{
  "source": [
    "aws.glue"
  ],
  "detail-type": [
    "Glue Data Catalog Database State Change",
    "Glue Data Catalog Table State Change"
  ]
}
EOF
}

resource "aws_cloudwatch_event_target" "metadata_change" {
  rule      = aws_cloudwatch_event_rule.metadata_change.name
  target_id = "LambdaReplicate"
  arn       = aws_lambda_function.replicate.arn
}

resource "aws_sfn_state_machine" "data_quality" {
  name       = "sdlf-data-quality-sm"
  role_arn   = aws_iam_role.states_execution.arn
  definition = data.template_file.sfn_definition.rendered
}

data "template_file" "sfn_definition" {
  template = file("${path.module}/statemachines/data-quality-definition.json")

  vars = {
    step1_lambda          = aws_lambda_function.step1.arn
    step2_lambda          = aws_lambda_function.step2.arn
    job_check_step_lambda = aws_lambda_function.job_check_step.arn
  }
}

########### GLUE ##############

resource "aws_s3_object" "scripts" {
  for_each = local.glue_scripts
  bucket   = var.pipeline_bucket
  key      = join("/", [local.glue_scripts_directory, "scripts", each.value])
  source   = join("/", [path.module, "scripts", local.glue_scripts_directory, each.value])
  etag     = filemd5(join("/", [path.module, "scripts", local.glue_scripts_directory, each.value]))
}

resource "aws_glue_job" "controller" {
  name         = "sdlf-data-quality-controller"
  role_arn     = var.datalake_admin_role_arn
  timeout      = 65
  glue_version = "1.0"

  execution_property {
    max_concurrent_runs = 10
  }

  command {
    name            = "pythonshell"
    python_version  = "3"
    script_location = join("/", ["s3:/", var.pipeline_bucket, aws_s3_object.scripts["controller"].id])
  }

  default_arguments = {
    "--TempDir"          = "s3://${var.pipeline_bucket}/${local.glue_scripts_directory}/"
    "--enable-metrics"   = "true"
    "--env"              = var.environment
    "--team"             = "default"
    "--dataset"          = "default"
    "--glueDatabase"     = "default"
    "--glueTables"       = "table1,table2"
    "--targetBucketName" = "s3://${var.data_quality_bucket}"
  }
}

resource "aws_glue_job" "suggestion_analysis" {
  name              = "sdlf-data-quality-suggestion-analysis-verification-runner"
  role_arn          = var.datalake_admin_role_arn
  timeout           = 60
  max_retries       = 0
  glue_version      = "2.0"
  number_of_workers = 3
  worker_type       = "G.1X"

  execution_property {
    max_concurrent_runs = 10
  }

  command {
    name            = "glueetl"
    script_location = join("/", ["s3:/", var.pipeline_bucket, aws_s3_object.scripts["suggestion-analysis"].id])
  }

  default_arguments = {
    "--TempDir"                          = "s3://${var.pipeline_bucket}/${local.glue_scripts_directory}/"
    "--job-language"                     = "scala"
    "--class"                            = "GlueApp"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--enable-metrics"                   = "true"
    "--enable-glue-datacatalog"          = ""
    "--extra-jars"                       = join("/", ["s3:/", var.pipeline_bucket, aws_s3_object.scripts["jar"].id])
    "--dynamodbSuggestionTableName"      = "octagon-DataQualitySuggestions-${var.environment}"
    "--dynamodbAnalysisTableName"        = "octagon-DataQualityAnalysis-${var.environment}"
    "--team"                             = "default"
    "--dataset"                          = "default"
    "--glueDatabase"                     = "default"
    "--glueTables"                       = "table1,table2"
    "--targetBucketName"                 = "s3://${var.data_quality_bucket}"
  }
}

resource "aws_glue_job" "analysis" {
  name              = "sdlf-data-quality-analysis-verification-runner"
  role_arn          = var.datalake_admin_role_arn
  timeout           = 60
  glue_version      = "2.0"
  max_retries       = 0
  number_of_workers = 3
  worker_type       = "G.1X"

  execution_property {
    max_concurrent_runs = 10
  }

  command {
    name            = "glueetl"
    script_location = join("/", ["s3:/", var.pipeline_bucket, aws_s3_object.scripts["analysis"].id])
  }

  default_arguments = {
    "--TempDir"                          = "s3://${var.pipeline_bucket}/${local.glue_scripts_directory}/"
    "--job-language"                     = "scala"
    "--class"                            = "GlueApp"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--enable-metrics"                   = "true"
    "--enable-glue-datacatalog"          = ""
    "--extra-jars"                       = join("/", ["s3:/", var.pipeline_bucket, aws_s3_object.scripts["jar"].id])
    "--dynamodbSuggestionTableName"      = "octagon-DataQualitySuggestions-${var.environment}"
    "--dynamodbAnalysisTableName"        = "octagon-DataQualityAnalysis-${var.environment}"
    "--team"                             = "default"
    "--dataset"                          = "default"
    "--glueDatabase"                     = "default"
    "--glueTables"                       = "table1,table2"
    "--targetBucketName"                 = "s3://${var.data_quality_bucket}"
  }
}

resource "aws_glue_job" "profile" {
  name              = "sdlf-data-quality-profile-runner"
  role_arn          = var.datalake_admin_role_arn
  timeout           = 60
  glue_version      = "2.0"
  max_retries       = 0
  number_of_workers = 3
  worker_type       = "G.1X"

  execution_property {
    max_concurrent_runs = 10
  }

  command {
    name            = "glueetl"
    script_location = join("/", ["s3:/", var.pipeline_bucket, aws_s3_object.scripts["profile"].id])
  }

  default_arguments = {
    "--TempDir"                          = "s3://${var.pipeline_bucket}/${local.glue_scripts_directory}/"
    "--job-language"                     = "scala"
    "--class"                            = "GlueApp"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--enable-metrics"                   = "true"
    "--enable-glue-datacatalog"          = ""
    "--extra-jars"                       = join("/", ["s3:/", var.pipeline_bucket, aws_s3_object.scripts["jar"].id])
    "--team"                             = "default"
    "--dataset"                          = "default"
    "--glueDatabase"                     = "default"
    "--glueTables"                       = "table1,table2"
    "--targetBucketName"                 = "s3://${var.data_quality_bucket}"
  }
}

resource "aws_glue_catalog_database" "this" {
  name        = join("_", [var.organization_name, var.application_name, var.environment, "data_quality_db"])
  description = "data quality metadata catalog"
  catalog_id  = data.aws_caller_identity.current.account_id
}

resource "aws_glue_crawler" "this" {
  database_name = aws_glue_catalog_database.this.name
  name          = "sdlf-data-quality-crawler"
  role          = var.datalake_admin_role_arn

  s3_target {
    path = join("", ["s3://", var.data_quality_bucket])
  }
}

resource "aws_lakeformation_permissions" "glue" {
  principal   = var.datalake_admin_role_arn
  permissions = ["CREATE_TABLE", "ALTER", "DROP"]

  database {
    name = aws_glue_catalog_database.this.name
  }

  lifecycle {
    ignore_changes = [permissions]
  }
}

resource "aws_ssm_parameter" "statemachine" {
  name        = "/SDLF/SM/DataQualityStateMachine"
  type        = "String"
  value       = aws_sfn_state_machine.data_quality.id
  description = "Data Quality State Machine"
}
