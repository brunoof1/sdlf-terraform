# Centralized Logging Solution

locals {
  send_data = {
    "SendAnonymousData" : "Yes"
  }
  instance_sizing = {
    "small"  = "i3.large.elasticsearch"
    "medium" = "i3.2xlarge.elasticsearch"
    "large"  = "i3.4xlarge.elasticsearch"
  }
  master_sizing = {
    "small"  = "c4.large.elasticsearch"
    "medium" = "c4.large.elasticsearch"
    "large"  = "c4.large.elasticsearch"
  }
  elasticsearch_node_count = {
    "small"  = 2
    "medium" = 4
    "large"  = 6
  }
  source_code = {
    "general" = {
      "s3_bucket"  = "solutions",
      "key_prefix" = "centralized-logging/v3.0.0"
    }
  }
  lambda_runtime     = "python3.7"
  lambda_handler     = "lambda_function.lambda_handler"
  principal_accounts = length(var.spoke_accounts) == 0 ? [data.aws_caller_identity.current.account_id] : var.spoke_accounts
  kms_key_arn        = data.aws_kms_key.this.arn
}

# lookups
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_kms_key" "this" {
  key_id = var.kms_key_id
}


######## DATALAKE SPECIFIC RESOURCES #########
######## CLOUDWATCH STREAMS #########
resource "aws_cloudwatch_log_subscription_filter" "this" {
  for_each        = toset(var.lambda_functions)
  name            = join("-", ["sdlf-log-stream", each.value])
  log_group_name  = join("", ["/aws/lambda/", each.value])
  filter_pattern  = "[log_type, log_timestamp, log_id, log_message]"
  destination_arn = aws_lambda_function.log_streamer.arn
}

resource "aws_iam_role" "elasticsearch" {
  name               = "sdlf-elasticsearch"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com",
          "logs.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "elasticsearch" {
  name   = "UpdateSubscriptionFilterPolicy"
  role   = aws_iam_role.elasticsearch.id
  policy = data.aws_iam_policy_document.elasticsearch.json
}

data "aws_iam_policy_document" "elasticsearch" {
  statement {
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:DescribeSubscriptionFilters",
      "logs:PutSubscriptionFilter",
      "logs:DeleteSubscriptionFilter"
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:*:log-stream*"
    ]
  }

  statement {
    actions = [
      "lambda:InvokeFunction",
      "lambda:GetFunction",
      "lambda:ListFunctions"
    ]
    resources = [
      "*"
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
}

# Log Streamer
resource "aws_iam_role" "log_streamer" {
  name               = "sdlf-log-streamer"
  path               = "/"
  assume_role_policy = <<EOF
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

resource "aws_iam_role_policy" "log_streamer" {
  name   = "logstreamer-${data.aws_region.current.name}"
  role   = aws_iam_role.log_streamer.id
  policy = data.aws_iam_policy_document.log_streamer.json
}

data "aws_iam_policy_document" "log_streamer" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
    ]
  }

  statement {
    actions = [
      "es:DescribeElasticsearchDomain",
      "es:DescribeElasticsearchDomains",
      "es:DescribeElasticsearchDomainConfig",
      "es:ESHttpPost",
      "es:ESHttpGet",
      "es:ESHttpPut"
    ]
    resources = [
      "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/*"
    ]
  }

  statement {
    actions = [
      "dynamodb:DescribeStream",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:ListStreams"
    ]

    resources = [
      var.object_metadata_stream_arn
    ]
  }

  statement {
    actions = [
      "sts:AssumeRole",
    ]
    resources = [
      aws_iam_role.logging_master.arn
    ]
  }
}

resource "aws_lambda_function" "log_streamer" {
  function_name = join("-", ["sdlf", "log-streamer"])
  description   = "Centralized Logging - Lambda function to stream logs on ES Domain"
  role          = aws_iam_role.log_streamer.arn
  handler       = "index.handler"
  runtime       = "nodejs12.x"
  timeout       = 300
  s3_bucket     = join("-", [local.source_code["general"]["s3_bucket"], data.aws_region.current.name])
  s3_key        = join("/", [local.source_code["general"]["key_prefix"], "clog-indexing-service.zip"])

  environment {
    variables = {
      LOG_LEVEL       = "INFO", #change to WARN, ERROR or DEBUG as needed
      DOMAIN_ENDPOINT = aws_elasticsearch_domain.this.endpoint,
      MASTER_ROLE     = aws_iam_role.logging_master.name,
      SESSION_ID      = "${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}",
      OWNER           = "Hub",
      SOLUTION        = "SO0009",
      CLUSTER_SIZE    = var.cluster_size,
      UUID            = random_uuid.log_streamer_uuid.result,
      ANONYMOUS_DATA  = local.send_data["SendAnonymousData"]
    }
  }
}

resource "random_uuid" "log_streamer_uuid" {}

resource "aws_lambda_permission" "log_streamer" {
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.log_streamer.function_name
  principal      = "logs.${data.aws_region.current.name}.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# bundle code
data "archive_file" "catalog_index" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/catalog-search/src/"
  output_path = "${path.module}/lambda/catalog-search/catalog-search.zip"
}

resource "aws_lambda_function" "catalog_index" {
  function_name    = join("-", ["sdlf", "catalog-search"])
  description      = "Logs ObjectMetadata DynamoDB Streams to ElasticSearch"
  role             = aws_iam_role.log_streamer.arn
  handler          = "index.handler"
  runtime          = "nodejs12.x"
  timeout          = 180
  memory_size      = 256
  source_code_hash = data.archive_file.catalog_index.output_base64sha256
  filename         = data.archive_file.catalog_index.output_path

  environment {
    variables = {
      ES_ENDPOINT = aws_elasticsearch_domain.this.endpoint,
      ES_REGION   = data.aws_region.current.name
    }
  }
}

resource "aws_lambda_event_source_mapping" "example" {
  event_source_arn  = var.object_metadata_stream_arn
  function_name     = aws_lambda_function.catalog_index.arn
  starting_position = "LATEST"
}

######## ELASTIC SEARCH STACK SPECIFIC #########
#
# Cognito and IAM
#
# Creates a user pool in cognito to auth against
resource "aws_cognito_user_pool" "this" {
  name                       = join("_", [var.domain_name, "kibana", "access"])
  auto_verified_attributes   = ["email"]
  mfa_configuration          = "OFF"
  email_verification_subject = join("-", [var.domain_name, "kibana", "access"])

  schema {
    name                     = "name"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = true

    string_attribute_constraints {
      max_length = "2048"
      min_length = "0"
    }
  }

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = false
    required                 = true

    string_attribute_constraints {
      max_length = "2048"
      min_length = "0"
    }
  }
}

resource "aws_cognito_user_group" "this" {
  name         = join("_", [var.domain_name, "kibana_access_group"])
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "User pool group for Kibana access"
  precedence   = 0
}

resource "aws_cognito_user_pool_client" "this" {
  name            = join("-", [var.domain_name, "client"])
  generate_secret = false
  user_pool_id    = aws_cognito_user_pool.this.id
}

resource "aws_cognito_identity_pool" "this" {
  identity_pool_name               = join("", [var.domain_name, "Identity"])
  allow_unauthenticated_identities = true

  cognito_identity_providers {
    client_id     = aws_cognito_user_pool_client.this.id
    provider_name = aws_cognito_user_pool.this.endpoint
  }
}

resource "aws_iam_role" "unauthorized" {
  name               = "cognito-unauthorized"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Effect": "Allow",
      "Condition": {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.this.id}"
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "unauthenticated"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "unauthorized" {
  name = "CognitoUnauthorizedPolicy"
  role = aws_iam_role.unauthorized.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "mobileanalytics:PutEvents",
          "cognito-sync:BulkPublish",
          "cognito-sync:DescribeIdentityPoolUsage",
          "cognito-sync:GetBulkPublishDetails",
          "cognito-sync:GetCognitoEvents",
          "cognito-sync:GetIdentityPoolConfiguration",
          "cognito-sync:ListIdentityPoolUsage",
          "cognito-sync:SetCognitoEvents",
          "cognito-sync:SetIdentityPoolConfiguration"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:cognito-identity:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:identitypool/${aws_cognito_identity_pool.this.id}"
      }
    ]
  }
  EOF
}

resource "aws_iam_role" "authorized" {
  name               = "cognito-authorized"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Effect": "Allow",
      "Condition": {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.this.id}"
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "authenticated"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "authorized" {
  name = "CognitoAuthorizedPolicy"
  role = aws_iam_role.authorized.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "mobileanalytics:PutEvents",
          "cognito-sync:BulkPublish",
          "cognito-sync:DescribeIdentityPoolUsage",
          "cognito-sync:GetBulkPublishDetails",
          "cognito-sync:GetCognitoEvents",
          "cognito-sync:GetIdentityPoolConfiguration",
          "cognito-sync:ListIdentityPoolUsage",
          "cognito-sync:SetCognitoEvents",
          "cognito-sync:SetIdentityPoolConfiguration",
          "cognito-identity:DeleteIdentityPool",
          "cognito-identity:DescribeIdentityPool",
          "cognito-identity:GetIdentityPoolRoles",
          "cognito-identity:GetOpenIdTokenForDeveloperIdentity",
          "cognito-identity:ListIdentities",
          "cognito-identity:LookupDeveloperIdentity",
          "cognito-identity:MergeDeveloperIdentities",
          "cognito-identity:UnlikeDeveloperIdentity",
          "cognito-identity:UpdateIdentityPool"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:cognito-identity:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:identitypool/${aws_cognito_identity_pool.this.id}"
      }
    ]
  }
  EOF
}

resource "aws_iam_role" "elasticsearch_access" {
  name               = "elasticsearch-access"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "elasticsearch_access" {
  role       = aws_iam_role.elasticsearch_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonESCognitoAccess"
}

resource "aws_cognito_identity_pool_roles_attachment" "this" {
  identity_pool_id = aws_cognito_identity_pool.this.id

  roles = {
    "authenticated"   = aws_iam_role.authorized.arn,
    "unauthenticated" = aws_iam_role.unauthorized.arn
  }
}

# WAITING FOR TERRAFORM LAKEFORMATION SUPPORT
resource "aws_cloudformation_stack" "admin_user" {
  name          = "sdlf-cognito-admin-user"
  template_body = <<STACK
Resources:
  AdminUser:
    Type: 'AWS::Cognito::UserPoolUser'
    Properties:
      DesiredDeliveryMediums:
        - 'EMAIL'
      UserAttributes:
        - Name: email
          Value: ${var.cognito_admin_email}
      Username: ${var.cognito_admin_email}
      UserPoolId: ${aws_cognito_user_pool.this.id}
STACK
}

resource "aws_lambda_function" "setup_es_cognito" {
  function_name = join("-", ["sdlf", "setup-es-cognito"])
  description   = "Centralized Logging - Lambda function to enable cognito authentication for kibana"
  role          = aws_iam_role.es_cognito.arn
  handler       = "index.handler"
  runtime       = "nodejs12.x"
  timeout       = 300
  s3_bucket     = join("-", [local.source_code["general"]["s3_bucket"], data.aws_region.current.name])
  s3_key        = join("/", [local.source_code["general"]["key_prefix"], "clog-auth.zip"])

  environment {
    variables = {
      LOG_LEVEL = "INFO" #change to WARN, ERROR or DEBUG as needed
    }
  }
}

data "aws_lambda_invocation" "setup_es_cognito" {
  function_name = aws_lambda_function.setup_es_cognito.function_name
  input = jsonencode(
    {
      "UserPoolId" : aws_cognito_user_pool.this.id,
      "CognitoDomain" : join("-", [var.domain_name, data.aws_caller_identity.current.account_id]),
      "Domain" : var.domain_name,
      "ServiceToken" : aws_iam_role.es_cognito.arn,
      "IdentityPoolId" : aws_cognito_identity_pool.this.id,
      "RoleArn" : aws_iam_role.elasticsearch_access.arn
    }
  )
}


resource "aws_iam_role" "es_cognito" {
  name               = "sdlf-lambda-setup-cognito"
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

resource "aws_iam_role_policy" "es_cognito" {
  name   = "setup-es-cognito"
  role   = aws_iam_role.es_cognito.id
  policy = data.aws_iam_policy_document.es_cognito.json
}

data "aws_iam_policy_document" "es_cognito" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }

  statement {
    actions = [
      "es:UpdateElasticsearchDomainConfig"
    ]
    resources = [
      "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.domain_name}"
    ]
  }

  statement {
    actions = [
      "cognito-idp:CreateUserPoolDomain",
      "cognito-idp:DeleteUserPoolDomain"
    ]
    resources = [
      aws_cognito_user_pool.this.arn
    ]
  }

  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [
      aws_iam_role.elasticsearch_access.arn
    ]
  }
}

# Primer Elasticsearch resources

resource "aws_iam_role" "logging_master" {
  name               = "sdlf-logging-master"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.logging_master_assume_role_policy.json
}

data "aws_iam_policy_document" "logging_master_assume_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "AWS"
      identifiers = local.principal_accounts
    }
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "logging_master" {
  name   = "sdlf-logging-master"
  role   = aws_iam_role.logging_master.id
  policy = data.aws_iam_policy_document.logging_master.json
}

data "aws_iam_policy_document" "logging_master" {
  statement {
    actions = [
      "es:ESHttpPost"
    ]
    resources = [
      "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/*"
    ]
  }
}


resource "aws_elasticsearch_domain" "this" {
  domain_name           = var.domain_name
  elasticsearch_version = "6.3"
  access_policies       = data.aws_iam_policy_document.elasticsearch_access.json

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_id
  }

  cluster_config {
    dedicated_master_enabled = true
    instance_count           = local.elasticsearch_node_count[var.cluster_size]
    zone_awareness_enabled   = true
    instance_type            = local.instance_sizing[var.cluster_size]
    dedicated_master_type    = local.master_sizing[var.cluster_size]
    dedicated_master_count   = 3
  }

  snapshot_options {
    automated_snapshot_start_hour = 1
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true",
    "indices.fielddata.cache.size"           = "40"
  }

}

data "aws_iam_policy_document" "elasticsearch_access" {
  statement {
    actions = [
      "es:*"
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.logging_master.arn]
    }

    resources = [
      "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/*"
    ]
  }

  statement {
    actions = [
      "es:*"
    ]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/${aws_iam_role.authorized.name}/CognitoIdentityCredentials"
      ]
    }

    resources = [
      "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.domain_name}/*"
    ]
  }
}

#
# SNS Topic
#

resource "aws_sns_topic" "cloudwatch_alarms" {
  name = "sdlf-centralized-logging"
}

resource "aws_sns_topic_policy" "cloudwatch_alarms" {
  arn    = aws_sns_topic.cloudwatch_alarms.arn
  policy = data.aws_iam_policy_document.cloudwatch_alarms.json
}

data "aws_iam_policy_document" "cloudwatch_alarms" {
  statement {
    actions = [
      "sns:Publish"
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }

    resources = [
      aws_sns_topic.cloudwatch_alarms.arn,
    ]
  }
}

# No Email Support
# resource "aws_sns_topic_subscription" "cloudwatch_alarms" {
#   topic_arn = aws_sns_topic.cloudwatch_alarms.arn
#   protocol  = "email"
#   endpoint  = var.domain_admin_email
# }

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "status_yellow_alarm" {
  alarm_name          = "sdlf-elasticsearch-status-yellow"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  alarm_description   = "Replica shards for at least one index are not allocated to nodes in a cluster."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ClusterStatus.yellow"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  ok_actions = [
    aws_sns_topic.cloudwatch_alarms.arn
  ]

  dimensions = {
    ClientId   = data.aws_caller_identity.current.account_id,
    DomainName = var.domain_name
  }
}

resource "aws_cloudwatch_metric_alarm" "status_red_alarm" {
  alarm_name          = "sdlf-elasticsearch-status-red"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  alarm_description   = "Primary and replica shards of at least one index are not allocated to nodes in a cluster."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ClusterStatus.red"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  ok_actions = [
    aws_sns_topic.cloudwatch_alarms.arn
  ]

  dimensions = {
    ClientId   = data.aws_caller_identity.current.account_id,
    DomainName = var.domain_name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "sdlf-elasticsearch-cpu-high"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  alarm_description   = "Average CPU utilization over last 45 minutes too high."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ES"
  period              = "900"
  statistic           = "Average"
  threshold           = "80"
  ok_actions = [
    aws_sns_topic.cloudwatch_alarms.arn
  ]

  dimensions = {
    ClientId   = data.aws_caller_identity.current.account_id,
    DomainName = var.domain_name
  }
}

resource "aws_cloudwatch_metric_alarm" "master_cpu_high" {
  alarm_name          = "sdlf-elasticsearch-master-cpu-high"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  alarm_description   = "Average CPU utilization over last 45 minutes too high."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "3"
  metric_name         = "MasterCPUUtilization"
  namespace           = "AWS/ES"
  period              = "900"
  statistic           = "Average"
  threshold           = "50"
  ok_actions = [
    aws_sns_topic.cloudwatch_alarms.arn
  ]

  dimensions = {
    ClientId   = data.aws_caller_identity.current.account_id,
    DomainName = var.domain_name
  }
}

resource "aws_cloudwatch_metric_alarm" "free_storage_low" {
  alarm_name          = "sdlf-elasticsearch-free-storage-low"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  alarm_description   = "Cluster has less than 2GB of storage space."
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "2000"
  ok_actions = [
    aws_sns_topic.cloudwatch_alarms.arn
  ]

  dimensions = {
    ClientId   = data.aws_caller_identity.current.account_id,
    DomainName = var.domain_name
  }
}

resource "aws_cloudwatch_metric_alarm" "index_writes_blocked" {
  alarm_name          = "sdlf-elasticsearch-index-writes-blocked"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  alarm_description   = "Cluster is blocking incoming write requests."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ClusterIndexWritesBlocked"
  namespace           = "AWS/ES"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "1"
  ok_actions = [
    aws_sns_topic.cloudwatch_alarms.arn
  ]

  dimensions = {
    ClientId   = data.aws_caller_identity.current.account_id,
    DomainName = var.domain_name
  }
}

resource "aws_cloudwatch_metric_alarm" "jvm_memory_pressure" {
  alarm_name          = "sdlf-elasticsearch-jvm-memory-pressure"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  alarm_description   = "Average JVM memory pressure over last 15 minutes too high."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "JVMMemoryPressure"
  namespace           = "AWS/ES"
  period              = "900"
  statistic           = "Average"
  threshold           = "80"
  ok_actions = [
    aws_sns_topic.cloudwatch_alarms.arn
  ]

  dimensions = {
    ClientId   = data.aws_caller_identity.current.account_id,
    DomainName = var.domain_name
  }
}

resource "aws_cloudwatch_metric_alarm" "master_jvm_memory_pressure" {
  alarm_name          = "sdlf-elasticsearch-master-jvm-memory-pressure"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  alarm_description   = "Average JVM memory pressure over last 15 minutes too high."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "MasterJVMMemoryPressure"
  namespace           = "AWS/ES"
  period              = "900"
  statistic           = "Average"
  threshold           = "50"
  ok_actions = [
    aws_sns_topic.cloudwatch_alarms.arn
  ]

  dimensions = {
    ClientId   = data.aws_caller_identity.current.account_id,
    DomainName = var.domain_name
  }
}

resource "aws_cloudwatch_metric_alarm" "master_not_reachable" {
  alarm_name          = "sdlf-elasticsearch-master-not-reachable"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  alarm_description   = "Master node stopped or not reachable. Usually the result of a network connectivity issue or AWS dependency problem."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "MasterReachableFromNode"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  ok_actions = [
    aws_sns_topic.cloudwatch_alarms.arn
  ]

  dimensions = {
    ClientId   = data.aws_caller_identity.current.account_id,
    DomainName = var.domain_name
  }
}

resource "aws_cloudwatch_metric_alarm" "snapshot_failure" {
  alarm_name          = "sdlf-elasticsearch-snapshot-failure"
  alarm_actions       = [aws_sns_topic.cloudwatch_alarms.arn]
  alarm_description   = "No automated snapshot was taken for the domain in the previous 36 hours."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "AutomatedSnapshotFailure"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  ok_actions = [
    aws_sns_topic.cloudwatch_alarms.arn
  ]

  dimensions = {
    ClientId   = data.aws_caller_identity.current.account_id,
    DomainName = var.domain_name
  }
}
