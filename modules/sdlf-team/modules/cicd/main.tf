# Description: "CICD Resources to manage a team"

# lookups
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_kms_key" "infra" {
  key_id = var.kms_infra_key_id
}

# resources
resource "aws_sns_topic" "this" {
  name              = "sdlf-${var.team_name}-notification"
  kms_master_key_id = var.kms_infra_key_id
}

resource "aws_sns_topic_policy" "this" {
  arn = aws_sns_topic.this.arn

  policy = data.aws_iam_policy_document.this_sns.json
}

data "aws_iam_policy_document" "this_sns" {
  policy_id = "sdlf-${var.team_name}-notifications"

  statement {
    sid = "sdlf-${var.team_name}-notifications"

    actions = [
      "sns:Publish"
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    resources = [
      aws_sns_topic.this.arn
    ]
  }
}

######## CODECOMMIT #########
resource "aws_codecommit_repository" "datalake_library_layer" {
  repository_name = var.datalake_library_repository_name
  description     = "The data lake library repository is where a team pushes the transformation code (i.e. business logic) that they wish to apply to their datasets."
  default_branch  = var.libraries_branch_name
}

resource "aws_codecommit_repository" "pip_libraries" {
  repository_name = var.pip_libraries_repository_name
  description     = "This repository contains the `requirements.txt` files that should be turned into Lambda Layers. These Lambda Layers can be shared across all the Lambda functions owned by a team, and should contain the libraries that are commonly used across the Lambda functions."
  default_branch  = var.libraries_branch_name
}

resource "aws_iam_role" "codecommit" {
  name               = "sdlf-${var.team_name}-${var.environment}-codecommit"
  description        = "Role assumed by CodeBuild/CodePipeline"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codecommit" {
  name   = "sdlf-${var.team_name}-${var.environment}-codecommit"
  role   = aws_iam_role.codecommit.id
  policy = data.aws_iam_policy_document.codecommit.json
}

data "aws_iam_policy_document" "codecommit" {
  statement {
    actions = [
      "codecommit:CreateApprovalRuleTemplate",
      "codecommit:DeleteApprovalRuleTemplate",
      "codecommit:GetApprovalRuleTemplate",
      "codecommit:ListApprovalRuleTemplates",
      "codecommit:ListRepositories",
      "codecommit:ListRepositoriesForApprovalRuleTemplate",
      "codecommit:UpdateApprovalRuleTemplateContent",
      "codecommit:UpdateApprovalRuleTemplateDescription",
      "codecommit:UpdateApprovalRuleTemplateName"
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
      aws_codecommit_repository.datalake_library_layer.arn,
      aws_codecommit_repository.pip_libraries.arn,
      "arn:aws:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stage*",
      "arn:aws:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:sdlf-${var.team_name}-*"
    ]
  }

  statement {
    actions = [
      "s3:Get*",
      "s3:ListBucket*",
      "s3:Put*"
    ]

    resources = [
      "arn:aws:s3:::${var.pipeline_bucket}",
      "arn:aws:s3:::${var.pipeline_bucket}/*"
    ]
  }

  statement {
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:List*",
      "kms:Describe*"
    ]

    resources = [
      "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
    ]

    condition {
      test     = "ForAllValues:StringLike"
      variable = "aws:PrincipalArn"
      values = [
        "*${var.team_name}*"
      ]

    }
  }
}

######## CODEBUILD JOBS #########
resource "aws_codebuild_project" "dataset_mappings" {
  name           = "sdlf-${var.team_name}-dataset-mappings"
  description    = "Updates octagon-Datasets DynamoDB entries with transforms"
  encryption_key = data.aws_kms_key.infra.arn
  service_role   = var.codebuild_service_role_arn
  queued_timeout = 60
  build_timeout  = 20

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:4.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "TEAM_NAME"
      value = var.team_name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "ENV_NAME"
      value = var.environment
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "LAMBDA_PUBLISHING_ROLE"
      value = var.codebuild_publish_layer_role_arn
      type  = "PLAINTEXT"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/files/buildspec-sdlf-dataset-mappings.yml")
  }
}

resource "aws_codebuild_project" "datalake_library_layer" {
  name           = "sdlf-${var.team_name}-${var.datalake_libs_lambda_layer_name}"
  description    = "Creates a Lambda Layer with the repository provided"
  encryption_key = data.aws_kms_key.infra.arn
  service_role   = var.codebuild_service_role_arn
  queued_timeout = 60
  build_timeout  = 20

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:4.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "TEAM_NAME"
      value = var.team_name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "LAYER_NAME"
      value = var.datalake_libs_lambda_layer_name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "LAMBDA_PUBLISHING_ROLE"
      value = var.codebuild_publish_layer_role_arn
      type  = "PLAINTEXT"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/files/buildspec-sdlf-datalake-library-layer.yml")
  }
}

resource "aws_codebuild_project" "team_unit_test" {
  count          = var.run_code_coverage == true ? 1 : 0
  name           = "sdlf-${var.team_name}-cicd-unit-test-coverage"
  encryption_key = data.aws_kms_key.infra.arn
  service_role   = var.codebuild_service_role_arn
  build_timeout  = 20

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:4.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "COV_PERCENT"
      value = var.minimum_test_coverage
      type  = "PLAINTEXT"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/files/buildspec-sdlf-team-unit-test.yml")
  }
}

resource "aws_codebuild_project" "requirements_layer" {
  name           = "sdlf-${var.team_name}-${var.default_pip_libraries_lambda_layer_name}"
  description    = "Creates a Lambda Layer containing the libraries and version numbers listed in the requirements.txt file in the repository provided"
  encryption_key = data.aws_kms_key.infra.arn
  service_role   = var.codebuild_service_role_arn
  build_timeout  = 20
  queued_timeout = 60

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:4.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "TEAM_NAME"
      value = var.team_name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "LAYER_NAME"
      value = var.default_pip_libraries_lambda_layer_name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "LAMBDA_PUBLISHING_ROLE"
      value = var.codebuild_publish_layer_role_arn
      type  = "PLAINTEXT"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/files/buildspec-sdlf-requirements-layer.yml")
  }
}

resource "aws_codebuild_project" "transform_validate" {
  name           = "sdlf-${var.team_name}-transform-validate"
  description    = "Transforms and validates Serverless templates"
  encryption_key = data.aws_kms_key.infra.arn
  service_role   = var.transform_validate_role_arn
  build_timeout  = 5
  queued_timeout = 60

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:4.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "TEAM_NAME"
      value = var.team_name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "ARTIFACTORY_BUCKET"
      value = var.pipeline_bucket
      type  = "PLAINTEXT"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/files/buildspec-sdlf-transform-validate.yml")
  }
}

######## LAMBDA LAYER PIPELINE #########
resource "aws_codepipeline" "common_datalake_libs" {
  count    = var.run_code_coverage == false ? 1 : 0
  name     = "sdlf-${var.team_name}-${var.datalake_libs_lambda_layer_name}"
  role_arn = var.codepipeline_role_arn

  artifact_store {
    location = var.pipeline_bucket
    type     = "S3"

    encryption_key {
      id   = var.kms_infra_key_id
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      role_arn         = aws_iam_role.codecommit.arn
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      run_order        = 1

      configuration = {
        RepositoryName       = aws_codecommit_repository.datalake_library_layer.repository_name
        BranchName           = var.libraries_branch_name
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "Map"

    action {
      name             = "Map"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["DatalakeRepositoryArtifact"]
      run_order        = 1

      configuration = {
        ProjectName = aws_codebuild_project.dataset_mappings.name
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["DatalakeRepositoryArtifact"]
      run_order       = 2

      configuration = {
        ProjectName = aws_codebuild_project.datalake_library_layer.name
      }
    }
  }
}

resource "aws_codepipeline" "common_datalake_test_libs" {
  count    = var.run_code_coverage == true ? 1 : 0
  name     = "sdlf-${var.team_name}-${var.datalake_libs_lambda_layer_name}"
  role_arn = var.codepipeline_role_arn

  artifact_store {
    location = var.pipeline_bucket
    type     = "S3"

    encryption_key {
      id   = var.kms_infra_key_id
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      role_arn         = aws_iam_role.codecommit.arn
      category         = "Source"
      owner            = "AWS"
      version          = "1"
      provider         = "CodeCommit"
      output_artifacts = ["SourceArtifact"]
      run_order        = 1

      configuration = {
        RepositoryName       = aws_codecommit_repository.datalake_library_layer.repository_name
        BranchName           = var.libraries_branch_name
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "Test"

    action {
      name            = "Test"
      category        = "Build"
      owner           = "AWS"
      version         = "1"
      provider        = "CodeBuild"
      input_artifacts = ["SourceArtifact"]
      run_order       = 1

      configuration = {
        ProjectName = aws_codebuild_project.team_unit_test[0].name
      }
    }
  }

  stage {
    name = "Map"

    action {
      name             = "Map"
      category         = "Build"
      owner            = "AWS"
      version          = "1"
      provider         = "CodeBuild"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["DatalakeRepositoryArtifact"]
      run_order        = 1

      configuration = {
        ProjectName = aws_codebuild_project.dataset_mappings.name
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      version         = "1"
      provider        = "CodeBuild"
      input_artifacts = ["DatalakeRepositoryArtifact"]
      run_order       = 1

      configuration = {
        ProjectName = aws_codebuild_project.datalake_library_layer.name
      }
    }
  }
}

resource "aws_codepipeline" "common_pip_libs" {
  name     = "sdlf-${var.team_name}-${var.default_pip_libraries_lambda_layer_name}"
  role_arn = var.codepipeline_role_arn

  artifact_store {
    location = var.pipeline_bucket
    type     = "S3"

    encryption_key {
      id   = var.kms_infra_key_id
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      role_arn         = aws_iam_role.codecommit.arn
      category         = "Source"
      owner            = "AWS"
      version          = "1"
      provider         = "CodeCommit"
      output_artifacts = ["SourceArtifact"]
      run_order        = 1

      configuration = {
        RepositoryName       = aws_codecommit_repository.pip_libraries.repository_name
        BranchName           = var.libraries_branch_name
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      version         = "1"
      provider        = "CodeBuild"
      input_artifacts = ["SourceArtifact"]
      run_order       = 1

      configuration = {
        ProjectName = aws_codebuild_project.requirements_layer.name
      }
    }
  }
}

####### CLOUDWATCH EVENTS RULES #########

resource "aws_cloudwatch_event_rule" "datalake_pipeline" {
  name        = "sdlf-${var.team_name}-${var.datalake_libs_lambda_layer_name}-trigger"
  description = "Trigger ${var.team_name} team Data Lake Library pipeline"

  event_pattern = <<EOF
{
  "source": [
    "aws.codecommit"
  ],
  "detail-type": [
    "CodeCommit Repository State Change"
  ],
  "resources": [
    "arn:aws:codecommit:${data.aws_region.current.name}:${var.shared_devops_account_id}:${var.datalake_library_repository_name}"
  ],
  "detail": {
    "event": [
      "referenceCreated",
      "referenceUpdated"
    ],
    "referenceType": [
      "branch"
    ],
    "referenceName": [
      "${var.libraries_branch_name}"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "datalake_pipeline" {
  rule      = aws_cloudwatch_event_rule.datalake_pipeline.name
  target_id = "sdlf-${var.team_name}-${var.datalake_libs_lambda_layer_name}-trigger"
  role_arn  = var.cloudwatch_repository_trigger_role_arn
  arn       = var.run_code_coverage == false ? aws_codepipeline.common_datalake_libs[0].arn : aws_codepipeline.common_datalake_test_libs[0].arn
}

resource "aws_cloudwatch_event_rule" "datalake_pipeline_failed" {
  name          = "sdlf-${var.team_name}-${var.datalake_libs_lambda_layer_name}-failure"
  description   = "Notify ${var.team_name} team of Data Lake Library pipeline failure"
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
      "${var.run_code_coverage == false ? aws_codepipeline.common_datalake_libs[0].arn : aws_codepipeline.common_datalake_test_libs[0].arn}"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "datalake_pipeline_failed" {
  rule      = aws_cloudwatch_event_rule.datalake_pipeline_failed.name
  target_id = "sdlf-${var.team_name}-${var.datalake_libs_lambda_layer_name}-failure"
  arn       = aws_sns_topic.this.arn
  input_transformer {
    input_template = var.run_code_coverage == false ? jsonencode("The Pipeline <pipeline> has failed. Go to https://console.aws.amazon.com/codepipeline/home?region=${data.aws_region.current.name}#/view/${aws_codepipeline.common_datalake_libs[0].name}") : jsonencode("The Pipeline <pipeline> has failed. Go to https://console.aws.amazon.com/codepipeline/home?region=${data.aws_region.current.name}#/view/${aws_codepipeline.common_datalake_test_libs[0].name}")
    input_paths = {
      "pipeline" = "$.detail.pipeline"
    }
  }
}

resource "aws_cloudwatch_event_rule" "pip_pipeline_trigger" {
  name          = "sdlf-${var.team_name}-${var.default_pip_libraries_lambda_layer_name}-trigger"
  description   = "Trigger ${var.team_name} team pip library pipeline"
  event_pattern = <<EOF
{
  "source": [
    "aws.codecommit"
  ],
  "detail-type": [
    "CodeCommit Repository State Change"
  ],
  "resources": [
    "arn:aws:codecommit:${data.aws_region.current.name}:${var.shared_devops_account_id}:${var.pip_libraries_repository_name}"
  ],
  "detail": {
    "event": [
      "referenceCreated",
      "referenceUpdated"
    ],
    "referenceType": [
      "branch"
    ],
    "referenceName": [
      "${var.libraries_branch_name}"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "pip_pipeline_trigger" {
  rule      = aws_cloudwatch_event_rule.pip_pipeline_trigger.name
  target_id = "sdlf-${var.team_name}-${var.default_pip_libraries_lambda_layer_name}-trigger"
  role_arn  = var.cloudwatch_repository_trigger_role_arn
  arn       = "arn:aws:codepipeline:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_codepipeline.common_pip_libs.name}"
}

resource "aws_cloudwatch_event_rule" "pip_pipeline_failed" {
  name          = "sdlf-${var.team_name}-${var.default_pip_libraries_lambda_layer_name}-failure"
  description   = "Notify ${var.team_name} team of Pip Library pipeline failure"
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
      "${aws_codepipeline.common_pip_libs.arn}"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "pip_pipeline_failed" {
  rule      = aws_cloudwatch_event_rule.pip_pipeline_failed.name
  target_id = "sdlf-${var.team_name}-${var.default_pip_libraries_lambda_layer_name}-failure"
  arn       = aws_sns_topic.this.arn
  input_transformer {
    input_template = jsonencode("The Pipeline <pipeline> has failed. Go to https://console.aws.amazon.com/codepipeline/home?region=${data.aws_region.current.name}#/view/${aws_codepipeline.common_pip_libs.name}")
    input_paths = {
      "pipeline" = "$.detail.pipeline"
    }
  }
}


######## SSM #########
resource "aws_ssm_parameter" "sns_topic" {
  name        = "/SDLF/SNS/${var.team_name}/Notifications"
  type        = "String"
  value       = aws_sns_topic.this.arn
  description = "The ARN of the team-specific SNS Topic"
}

resource "aws_ssm_parameter" "datalake_library_layer" {
  name        = "/SDLF/Lambda/${var.team_name}/LatestDatalakeLibraryLayer"
  type        = "String"
  value       = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:layer:${var.team_name}-${var.datalake_libs_lambda_layer_name}:1"
  description = "The ARN of the latest version of the Datalake Library layer"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "pip_libraries_layer" {
  name        = "/SDLF/Lambda/${var.team_name}/LatestDefaultPipLibraryLayer"
  type        = "String"
  value       = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:layer:${var.team_name}-${var.default_pip_libraries_lambda_layer_name}:1"
  description = "The ARN of the latest version of the Lambda Layer containing the Pip libraries"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "transform_validate_serverless_template" {
  name        = "/SDLF/CodeBuild/${var.team_name}/TransformValidateServerless"
  type        = "String"
  value       = aws_codebuild_project.transform_validate.name
  description = "The CodeBuild job that transforms and validates serverless CloudFormation templates"
}

resource "aws_ssm_parameter" "datalake_library_layer_build_project" {
  name        = "/SDLF/CodeBuild/${var.team_name}/BuildDeployDatalakeLibraryLayer"
  type        = "String"
  value       = aws_codebuild_project.datalake_library_layer.name
  description = "Name of the CodeBuild job that packages the Datalake Libs into a Lambda Layer"
}
