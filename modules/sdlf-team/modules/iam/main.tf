# Description: "IAM Resources to manage a team"

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  create_multiple_buckets = var.central_bucket != var.analytics_bucket ? true : false
  create_multiple_buckets_paths = [
    "arn:aws:s3:::${var.central_bucket}/${var.team_name}/*",
    "arn:aws:s3:::${var.central_bucket}/raw/${var.team_name}/*",
    "arn:aws:s3:::${var.analytics_bucket}/${var.team_name}/*",
    "arn:aws:s3:::${var.analytics_bucket}/analytics/${var.team_name}/*"
  ]
  common_bucket_paths = [
    "arn:aws:s3:::${var.pipeline_bucket}/${var.team_name}/*",
    "arn:aws:s3:::${var.stage_bucket}/${var.team_name}/*",
    "arn:aws:s3:::${var.stage_bucket}/pre-stage/${var.team_name}/*",
    "arn:aws:s3:::${var.stage_bucket}/stage/${var.team_name}/*",
    "arn:aws:s3:::${var.stage_bucket}/post-stage/${var.team_name}/*"
  ]
}


resource "aws_iam_policy" "team" {
  name        = "sdlf-${var.team_name}-permissions-boundary"
  description = "Team Permissions Boundary IAM policy. Add/remove permissions based on company policy and associate it to federated role"
  policy      = data.aws_iam_policy_document.team.json
}

data "aws_iam_policy_document" "team" {
  statement {
    sid = "AllowConsoleListBuckets"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListAllMyBuckets"
    ]
    resources = [
      "arn:aws:s3:::*"
    ]
  }

  statement {
    sid = "AllowTeamBucketList"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.pipeline_bucket}",
      "arn:aws:s3:::${var.central_bucket}",
      "arn:aws:s3:::${var.stage_bucket}",
      "arn:aws:s3:::${var.analytics_bucket}"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:Prefix"

      values = [
        "",
        "artifacts/",
        "raw/",
        "stage/",
        "pre-stage/",
        "post-stage/",
        "analytics/",
        var.team_name,
        "artifacts/${var.team_name}",
        "raw/${var.team_name}",
        "stage/${var.team_name}",
        "pre-stage/${var.team_name}",
        "post-stage/${var.team_name}",
        "analytics/${var.team_name}"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:delimiter"

      values = ["/"]
    }
  }

  statement {
    sid = "AllowTeamPrefixList"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.pipeline_bucket}",
      "arn:aws:s3:::${var.central_bucket}",
      "arn:aws:s3:::${var.stage_bucket}",
      "arn:aws:s3:::${var.analytics_bucket}"
    ]

    condition {
      test     = "StringLike"
      variable = "s3:Prefix"

      values = [
        "${var.team_name}/*",
        "artifacts/${var.team_name}/*",
        "raw/${var.team_name}/*",
        "stage/${var.team_name}/*",
        "pre-stage/${var.team_name}/*",
        "post-stage/${var.team_name}/*",
        "analytics/${var.team_name}/*",
      ]
    }
  }

  statement {
    sid = "AllowTeamPrefixActions"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
    resources = local.create_multiple_buckets == true ? concat(local.create_multiple_buckets_paths, local.common_bucket_paths) : local.common_bucket_paths
  }

  statement {
    sid = "AllowFullCodeCommitOnTeamRepositories"
    actions = [
      "codecommit:*"
    ]
    resources = [
      "arn:aws:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    sid = "AllowTeamKMSDataKeyUsage"
    actions = [
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant"
    ]
    resources = [
      var.kms_data_key_arn,
      var.kms_infra_key_arn
    ]
  }

  statement {
    sid = "AllowSSMGet"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/SDLF/*"
    ]
  }

  statement {
    sid = "AllowOctagonDynamoAccess"
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
    sid = "AllowSQSManagement"
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

  statement {
    sid = "AllowStatesExecution"
    actions = [
      "states:StartExecution"
    ]
    resources = [
      "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    sid = "StartGlueCrawler"
    actions = [
      "glue:StartCrawler"
    ]
    resources = [
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:crawler/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    sid = "GlueJobRuns"
    actions = [
      "glue:GetJobRun",
      "glue:StartJobRun"
    ]
    resources = [
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:job/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    sid = "LogGroups"
    actions = [
      "logs:CreateLogGroup"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }

  statement {
    sid = "AllowCloudWatchLogsReadOnlyAccess"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/sdlf-${var.team_name}-*",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/sdlf-${var.team_name}-*",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/jobs/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    sid = "AllowCloudFormationReadOnlyAccess"
    actions = [
      "cloudformation:DescribeStacks",
      "cloudformation:DescribeStackEvents",
      "cloudformation:DescribeStackResource",
      "cloudformation:DescribeStackResources"
    ]
    resources = [
      "arn:aws:cloudformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stack:sdlf-${var.team_name}:*"
    ]
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "sdlf-${var.team_name}-codepipeline"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "cloudformation.amazonaws.com",
          "codepipeline.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "sdlf-${var.team_name}-codepipeline"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline.json
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "*"
    ]

    condition {
      test     = "StringEqualsIfExists"
      variable = "iam:PassedToService"
      values = [
        "cloudformation.amazonaws.com",
        "lambda.amazonaws.com"
      ]
    }
  }

  statement {
    actions = [
      "iam:ListRoles"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"
    ]
  }

  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/sdlf-${var.team_name}-states-execution",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/state-machine/sdlf-${var.team_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/glue/sdlf-${var.team_name}-*",
      aws_iam_role.cloudwatch_events.arn,
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/EMR*"
    ]
  }

  statement {
    actions = [
      "iam:CreateRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/sdlf-${var.team_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/state-machine/sdlf-${var.team_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/sdlf-${var.team_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/glue/sdlf-${var.team_name}-*"
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.team.name]
    }
  }

  statement {
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/sdlf-${var.team_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/state-machine/sdlf-${var.team_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/sdlf-${var.team_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/glue/sdlf-${var.team_name}-*"
    ]
    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/sdlf-${var.team_name}-*"]
    }
  }

  statement {
    actions = [
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:PutRolePolicy",
      "iam:UntagRole",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
      "iam:TagRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/sdlf-${var.team_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/state-machine/sdlf-${var.team_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/sdlf-${var.team_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/glue/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "iam:ListPolicies",
      "iam:ListPolicyVersions"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/*"
    ]
  }

  statement {
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/sdlf-${var.team_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/state-machine/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "codecommit:CancelUploadArchive",
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:UploadArchive"
    ]
    resources = [
      "arn:aws:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:common-*",
      "arn:aws:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stage*",
      "arn:aws:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "events:DescribeRule",
      "events:PutRule",
      "events:DeleteRule",
      "events:RemoveTargets",
      "events:PutTargets"
    ]
    resources = [
      "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "lambda:ListFunctions",
      "lambda:GetLayerVersion"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:CreateFunction",
      "lambda:InvokeFunction",
      "lambda:UpdateFunctionConfiguration",
      "lambda:CreateAlias",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:PublishVersion",
      "lambda:UpdateAlias",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:GetFunctionConfiguration",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:ListTags",
      "lambda:DeleteFunctionConcurrency",
      "lambda:PutFunctionConcurrency"
    ]

    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:sdlf-${var.team_name}-*"
    ]

  }

  statement {
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:sdlf-foundations-kibana*"
    ]
  }

  statement {
    actions = [
      "lambda:CreateEventSourceMapping",
      "lambda:GetEventSourceMapping",
      "lambda:UpdateEventSourceMapping",
      "lambda:DeleteEventSourceMapping"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:DeleteStack",
      "cloudformation:DescribeStacks",
      "cloudformation:UpdateStack",
      "cloudformation:CreateChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:DescribeChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:SetStackPolicy"
    ]
    resources = [
      "arn:aws:cloudformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stack/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "cloudformation:DeleteChangeSet",
      "cloudformation:DescribeChangeSet",
      "cloudformation:CreateChangeSet",
      "cloudformation:ExecuteChangeSet"
    ]
    resources = [
      "arn:aws:cloudformation:${data.aws_region.current.name}:aws:transform/*"
    ]
  }

  statement {
    actions = [
      "cloudformation:ValidateTemplate"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codebuild:CreateProject",
      "codebuild:UpdateProject"
    ]
    resources = [
      "arn:aws:codebuild:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:project/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "states:ListStateMachines",
      "states:ListActivities",
      "states:CreateActivity",
      "states:CreateStateMachine",
      "states:TagResource"
    ]
    resources = [
      "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }

  statement {
    actions = [
      "states:DescribeStateMachine",
      "states:DescribeStateMachineForExecution",
      "states:DeleteStateMachine",
      "states:UpdateStateMachine"
    ]
    resources = [
      "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "states:DescribeActivity",
      "states:DeleteActivity",
      "states:GetActivityTask"
    ]
    resources = [
      "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:activity:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DeleteLogStream",
      "logs:DeleteLogGroup",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:TagLogGroup"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/sdlf-${var.team_name}-*:log-stream:*",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/sdlf-${var.team_name}-*:log-stream:*"
    ]
  }

  statement {
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:SetAlarmState",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:PutMetricData",
      "cloudwatch:DeleteAlarms"
    ]
    resources = [
      "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "sqs:ListQueues"
    ]
    resources = [
      "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }

  statement {
    actions = [
      "sqs:TagQueue",
      "sqs:AddPermission",
      "sqs:ChangeMessageVisibility",
      "sqs:CreateQueue",
      "sqs:DeleteQueue",
      "sqs:SetQueueAttributes",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:PutBucketAcl",
      "s3:PutBucketLogging",
      "s3:PutBucketVersioning",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy"
    ]
    resources = [
      "arn:aws:s3:::${var.pipeline_bucket}",
      "arn:aws:s3:::${var.pipeline_bucket}/*"
    ]
  }

  statement {
    actions = [
      "ssm:AddTagsToResource",
      "ssm:DescribeParameters",
      "ssm:GetOpsSummary",
      "ssm:GetParameter",
      "ssm:GetParameterHistory",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource",
      "ssm:RemoveTagsFromResource"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/SDLF/*"
    ]
  }

  statement {
    actions = [
      "ssm:PutParameter",
      "ssm:DeleteParameter"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/SDLF/*/${var.team_name}/*"
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
      var.kms_infra_key_arn
    ]
  }

  statement {
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      "arn:aws:iam::${var.shared_devops_account_id}:role/sdlf-${var.team_name}-${var.environment}-codecommit"
    ]
  }
}

resource "aws_iam_role" "cloudwatch_repository_trigger" {
  name               = "sdlf-${var.team_name}-cloudwatch-repository-trigger"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "events.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "cloudwatch_repository_trigger" {
  name   = "sdlf-${var.team_name}-cloudwatch-repository-trigger"
  role   = aws_iam_role.cloudwatch_repository_trigger.id
  policy = data.aws_iam_policy_document.cloudwatch_repository_trigger.json
}

data "aws_iam_policy_document" "cloudwatch_repository_trigger" {
  statement {
    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds"
    ]
    resources = [
      "arn:aws:codebuild:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "codepipeline:StartPipelineExecution"
    ]
    resources = [
      "arn:aws:codepipeline:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-${var.team_name}-*"
    ]
  }
}

resource "aws_iam_role" "transform_validate" {
  name               = "sdlf-${var.team_name}-transform-validate"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "codebuild.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "transform_validate" {
  name   = "sdlf-${var.team_name}-transform-validate"
  role   = aws_iam_role.transform_validate.id
  policy = data.aws_iam_policy_document.transform_validate.json
}

data "aws_iam_policy_document" "transform_validate" {
  statement {
    actions = [
      "cloudformation:ValidateTemplate"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "codecommit:Get*",
      "codecommit:Describe*",
      "codecommit:List*",
      "codecommit:GitPull",
      "codecommit:CancelUploadArchive",
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:UploadArchive"
    ]
    resources = [
      "arn:aws:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:common-*",
      "arn:aws:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stage-*",
      "arn:aws:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/sdlf-${var.team_name}*"
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::${var.pipeline_bucket}/*"
    ]
  }

  statement {
    actions = [
      "lambda:List*"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "lambda:GetLayer*"
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:layer:sdlf-${var.team_name}-*"
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
      var.kms_infra_key_arn
    ]
  }
}

resource "aws_iam_role" "cicd_codebuild" {
  name               = "sdlf-${var.team_name}-cicd-codebuild"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "codebuild.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "cicd_codebuild" {
  name   = "sdlf-${var.team_name}-cicd-codebuild"
  role   = aws_iam_role.cicd_codebuild.id
  policy = data.aws_iam_policy_document.cicd_codebuild.json
}

data "aws_iam_policy_document" "cicd_codebuild" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      "arn:aws:iam::${var.shared_devops_account_id}:role/sdlf-${var.environment}-${var.team_name}-codecommit"
    ]
  }

  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/sdlf-${var.team_name}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/sdlf-${var.team_name}-*",
      "arn:aws:iam::${var.shared_devops_account_id}:role/sdlf-${var.environment}-${var.team_name}-codecommit"
    ]
  }

  statement {
    actions = [
      "cloudformation:CreateChangeSet",
      "cloudformation:CreateStack",
      "cloudformation:DeleteChangeSet",
      "cloudformation:DeleteStack",
      "cloudformation:DescribeChangeSet",
      "cloudformation:DescribeStacks",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:SetStackPolicy",
      "cloudformation:UpdateStack"
    ]
    resources = [
      "arn:aws:cloudformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stack/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "cloudformation:CreateChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:DescribeChangeSet",
      "cloudformation:ExecuteChangeSet"
    ]
    resources = [
      "arn:aws:cloudformation:${data.aws_region.current.name}:aws:transform/*"
    ]
  }

  statement {
    actions = [
      "ssm:AddTagsToResource",
      "ssm:DescribeParameters",
      "ssm:GetOpsSummary",
      "ssm:GetParameter",
      "ssm:GetParameterHistory",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource",
      "ssm:RemoveTagsFromResource"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/SDLF/*"
    ]
  }

  statement {
    actions = [
      "ssm:DeleteParameter",
      "ssm:DeleteParameters",
      "ssm:PutParameter"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/SDLF/*/${var.team_name}/*"
    ]
  }

  statement {
    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Scan",
      "dynamodb:UpdateItem"
    ]
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/octagon-Pipelines-${var.environment}",
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/octagon-Datasets-${var.environment}"
    ]
  }

  statement {
    actions = [
      "events:DeleteRule",
      "events:DescribeRule",
      "events:DisableRule",
      "events:EnableRule",
      "events:PutRule",
      "events:PutTargets",
      "events:RemoveTargets"
    ]
    resources = [
      "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "codepipeline:CreatePipeline",
      "codepipeline:DeletePipeline",
      "codepipeline:GetPipelineState",
      "codepipeline:GetPipeline",
      "codepipeline:UpdatePipeline"
    ]
    resources = [
      "arn:aws:codepipeline:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "codebuild:BatchGetProjects",
      "codebuild:BatchGetBuilds",
      "codebuild:CreateProject",
      "codebuild:DeleteProject",
      "codebuild:UpdateProject"
    ]
    resources = [
      "arn:aws:codebuild:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:project/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.pipeline_bucket}"
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${var.pipeline_bucket}/*"
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
      var.kms_infra_key_arn
    ]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "lakeformation:GetDataAccess",
      "lakeformation:GrantPermissions",
      "lakeformation:RevokePermissions"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "sqs:AddPermission",
      "sqs:CreateQueue",
      "sqs:ChangeMessageVisibility",
      "sqs:ChangeMessageVisibilityBatch",
      "sqs:DeleteQueue",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueues",
      "sqs:ListQueueTags",
      "sqs:RemovePermission",
      "sqs:SendMessage",
      "sqs:SendMessageBatch",
      "sqs:SetQueueAttributes",
      "sqs:TagQueue",
      "sqs:UntagQueue"
    ]
    resources = [
      "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "glue:TagResource",
      "glue:UntagResource"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "glue:CreateCrawler",
      "glue:DeleteCrawler",
      "glue:GetCrawler",
      "glue:GetCrawlers",
      "glue:UpdateCrawler"
    ]
    resources = [
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:crawler/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "glue:CreateDatabase",
      "glue:DeleteDatabase",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:UpdateDatabase"
    ]
    resources = [
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${var.organization_name}_${var.application_name}_${var.environment}_${var.team_name}_*"
    ]
  }

  statement {
    actions = [
      "lambda:AddPermission",
      "lambda:RemovePermission"
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:sdlf-${var.team_name}*"
    ]
  }
}

resource "aws_iam_role" "codebuild_service" {
  name               = "sdlf-${var.team_name}-codebuild"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "codebuild.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_service" {
  name   = "sdlf-${var.team_name}-codebuild"
  role   = aws_iam_role.codebuild_service.id
  policy = data.aws_iam_policy_document.codebuild_service.json
}

data "aws_iam_policy_document" "codebuild_service" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "logs:CreateLogStream"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::${var.pipeline_bucket}/*",
    ]
  }

  statement {
    actions = [
      "codecommit:GitPull"
    ]
    resources = [
      "arn:aws:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:common-*",
      "arn:aws:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stage-*",
      "arn:aws:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-${var.team_name}-*"
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
      var.kms_infra_key_arn
    ]
  }
}

resource "aws_iam_role" "states_execution" {
  name               = "sdlf-${var.team_name}-states-execution"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "states.${data.aws_region.current.name}.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    },
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": [
          "${aws_iam_role.codepipeline.arn}"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "states_execution" {
  name   = "sdlf-${var.team_name}-states-execution"
  role   = aws_iam_role.states_execution.id
  policy = data.aws_iam_policy_document.states_execution.json
}

data "aws_iam_policy_document" "states_execution" {
  statement {
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "states:DescribeStateMachine",
      "states:DescribeStateMachineForExecution",
      "states:StartExecution"
    ]
    resources = [
      var.data_quality_state_machine
    ]
  }

  statement {
    actions = [
      "states:DescribeExecution",
      "states:StopExecution"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "events:DescribeRule",
      "events:PutTargets",
      "events:PutRule"
    ]
    resources = [
      "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForStepFunctionsExecutionRule"
    ]
  }

  statement {
    actions = [
      "elasticmapreduce:DescribeCluster",
      "elasticmapreduce:RunJobFlow",
      "elasticmapreduce:TerminateJobFlows"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "elasticmapreduce:AddJobFlowSteps",
      "elasticmapreduce:CancelSteps",
      "elasticmapreduce:DescribeStep",
      "elasticmapreduce:ListInstanceFleets",
      "elasticmapreduce:ListInstanceGroups",
      "elasticmapreduce:ModifyInstanceFleet",
      "elasticmapreduce:ModifyInstanceGroups",
      "elasticmapreduce:SetTerminationProtection"
    ]
    resources = [
      "arn:aws:elasticmapreduce:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/*"
    ]
  }

  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/EMR*"
    ]
  }

  statement {
    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:UpdateRoleDescription",
      "iam:PutRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/elasticmapreduce.amazonaws.com/AWSServiceRoleForEMRCleanup*"
    ]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["elasticmapreduce.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch_events" {
  name               = "sdlf-${var.team_name}-cloudwatch-event"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "events.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "trigger_lambda" {
  name   = "sdlf-${var.team_name}-trigger-lambda"
  role   = aws_iam_role.cloudwatch_events.id
  policy = data.aws_iam_policy_document.trigger_lambda.json
}

data "aws_iam_policy_document" "trigger_lambda" {
  statement {
    actions = [
      "lambda:ListFunctions"
    ]
    resources = ["*"
    ]
  }

  statement {
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:sdlf-${var.team_name}-*"
    ]
  }
}

resource "aws_iam_role_policy" "describe_state_machines" {
  name   = "sdlf-${var.team_name}-describe-state-machines"
  role   = aws_iam_role.cloudwatch_events.id
  policy = data.aws_iam_policy_document.describe_state_machines.json
}

data "aws_iam_policy_document" "describe_state_machines" {
  statement {
    actions = [
      "states:ListStateMachines"
    ]
    resources = [
      "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }
}

resource "aws_iam_role_policy" "dataset_state_machine" {
  name   = "sdlf-${var.team_name}-dataset-state-machine"
  role   = aws_iam_role.cloudwatch_events.id
  policy = data.aws_iam_policy_document.dataset_state_machine.json
}

data "aws_iam_policy_document" "dataset_state_machine" {
  statement {
    actions = [
      "states:DescribeStateMachineForExecution",
      "states:DescribeStateMachine",
      "states:StartExecution"
    ]
    resources = [
      "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning"
    ]
    resources = [
      "arn:aws:s3:::${var.pipeline_bucket}",
      "arn:aws:s3:::${var.central_bucket}",
      "arn:aws:s3:::${var.stage_bucket}",
      "arn:aws:s3:::${var.analytics_bucket}"
    ]
  }
}

resource "aws_iam_role" "codebuild_publish_layer" {
  name               = "sdlf-${var.team_name}-codebuild-publish-layer"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": [
          "${aws_iam_role.codebuild_service.arn}"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_publish_layer" {
  name   = "sdlf-${var.team_name}-codebuild-publish-layer"
  role   = aws_iam_role.codebuild_publish_layer.id
  policy = data.aws_iam_policy_document.codebuild_publish_layer.json
}

data "aws_iam_policy_document" "codebuild_publish_layer" {
  statement {
    actions = [
      "lambda:PublishLayerVersion"
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:layer:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "dynamodb:Get*",
      "dynamodb:Update*",
      "dynamodb:Put*"
    ]
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/octagon-*"
    ]
  }

  statement {
    actions = [
      "ssm:AddTagsToResource",
      "ssm:DescribeParameters",
      "ssm:GetOpsSummary",
      "ssm:GetParameter",
      "ssm:GetParameterHistory",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource",
      "ssm:RemoveTagsFromResource"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/SDLF/*"
    ]
  }

  statement {
    actions = [
      "ssm:PutParameter",
      "ssm:DeleteParameter"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/SDLF/*/${var.team_name}/*"
    ]
  }

  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${var.pipeline_bucket}",
      "arn:aws:s3:::${var.pipeline_bucket}/*"
    ]
  }
}


resource "aws_iam_role" "datalake_crawler" {
  name               = "sdlf-${var.team_name}-datalake-crawler"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "glue.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.datalake_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_crawler" {
  name   = "sdlf-${var.team_name}-glue-crawler"
  role   = aws_iam_role.datalake_crawler.id
  policy = data.aws_iam_policy_document.glue_crawler.json
}

data "aws_iam_policy_document" "glue_crawler" {
  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListAllMyBuckets"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "s3:CreateBucket"
    ]
    resources = [
      "arn:aws:s3:::aws-glue-*"
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::aws-glue-*/*",
      "arn:aws:s3:::*/*aws-glue-*/*"
    ]
  }

  statement {
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::crawler-public*",
      "arn:aws:s3:::aws-glue-*"
    ]
  }

  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:PutObject",
      "s3:PutObjectVersion"
    ]
    resources = [
      "arn:aws:s3:::${var.central_bucket}/${var.team_name}/*",
      "arn:aws:s3:::${var.central_bucket}/raw/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/stage/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/pre-stage/${var.team_name}/*",
      "arn:aws:s3:::${var.stage_bucket}/post-stage/${var.team_name}/*",
      "arn:aws:s3:::${var.analytics_bucket}/${var.team_name}/*",
      "arn:aws:s3:::${var.analytics_bucket}/analytics/${var.team_name}/*"
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
      var.kms_data_key_arn
    ]
  }
}

####### SSM #######

resource "aws_ssm_parameter" "team_iam_managed_policy" {
  name        = "/SDLF/IAM/${var.team_name}/TeamPermissionsBoundary"
  type        = "String"
  value       = aws_iam_policy.team.arn
  description = "The permissions boundary IAM Managed policy for the team"
}

resource "aws_ssm_parameter" "cloudwatch_event_state_machine_role_name" {
  name        = "/SDLF/IAM/${var.team_name}/CloudWatchEventStateMachineRole"
  type        = "String"
  value       = aws_iam_role.cloudwatch_events.name
  description = "The name of the CloudWatch Event role that triggers the State Machines"
}

resource "aws_ssm_parameter" "codepipeline_role_arn" {
  name        = "/SDLF/IAM/${var.team_name}/CodePipelineRoleArn"
  type        = "String"
  value       = aws_iam_role.codepipeline.arn
  description = "The ARN of the role used by CodePipeline"
}

resource "aws_ssm_parameter" "cloudwatch_repository_trigger_role_arn" {
  name        = "/SDLF/IAM/${var.team_name}/CloudWatchRepositoryTriggerRoleArn"
  type        = "String"
  value       = aws_iam_role.cloudwatch_repository_trigger.arn
  description = "The ARN of the CloudWatch Event role that triggers CodePipeline from CodeCommit"
}

resource "aws_ssm_parameter" "states_execution_role_arn" {
  name        = "/SDLF/IAM/${var.team_name}/StatesExecutionRoleArn"
  type        = "String"
  value       = aws_iam_role.states_execution.arn
  description = "The ARN of the States Execution role"
}

resource "aws_ssm_parameter" "datalake_crawler_role_arn" {
  name        = "/SDLF/IAM/${var.team_name}/CrawlerRoleArn"
  type        = "String"
  value       = aws_iam_role.datalake_crawler.arn
  description = "The ARN of the Crawler role"
}
