# Description: "KMS resources to manage a team"

# lookups
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


resource "aws_kms_key" "infra" {
  description         = join(" ", [var.team_name, "Infrastructure KMS Key"])
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.infra.json
}

data "aws_iam_policy_document" "infra" {
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
    sid = "Allow CloudWatch alarms access"
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
        "cloudwatch.amazonaws.com"
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
    sid = "Allow Routing Lambda and Shared DevOps access"
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
      "*"
    ]

    principals {
      type = "AWS"
      identifiers = [
        join(":", ["arn:aws:iam:", data.aws_caller_identity.current.account_id, "role/sdlf-routing"])
        #join("", ["arn:aws:iam::", var.shared_devops_account_id, ":role/sdlf-cicd-team-codecommit-", var.environment, var.team_name])
      ]
    }
  }

  statement {
    sid = "Allow DevOps account grant"
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]
    resources = [
      "*"
    ]

    principals {
      type = "AWS"
      identifiers = [
        join(":", ["arn:aws:iam:", data.aws_caller_identity.current.account_id, "role/sdlf-routing"])
        #join("", ["arn:aws:iam::", var.shared_devops_account_id, ":role/sdlf-cicd-team-codecommit-", var.environment, var.team_name])
      ]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"

      values = [
        true
      ]
    }
  }
}

resource "aws_kms_alias" "infra" {
  name          = join("-", ["alias/sdlf", var.team_name, "kms-infra-key"])
  target_key_id = aws_kms_key.infra.key_id
}

resource "aws_kms_key" "data" {
  description         = join(" ", [var.team_name, "Data KMS Key"])
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.data.json
}

data "aws_iam_policy_document" "data" {
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
    sid = "Allow Lake Formation permission"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [
      "*"
    ]

    principals {
      type        = "AWS"
      identifiers = [join("", ["arn:aws:iam::", data.aws_caller_identity.current.account_id, ":role/aws-service-role/lakeformation.amazonaws.com/AWSServiceRoleForLakeFormationDataAccess"])]
    }
  }
}

resource "aws_kms_alias" "data" {
  name          = join("-", ["alias/sdlf", var.team_name, "kms-data-key"])
  target_key_id = aws_kms_key.data.key_id
}

resource "aws_glue_security_configuration" "this" {
  name = join("-", ["sdlf", var.team_name, "glue-security-config"])

  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "SSE-KMS"
      kms_key_arn                = aws_kms_key.infra.arn
    }

    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "CSE-KMS"
      kms_key_arn                   = aws_kms_key.infra.arn
    }

    s3_encryption {
      kms_key_arn        = aws_kms_key.data.arn
      s3_encryption_mode = "SSE-KMS"
    }
  }
}

resource "aws_emr_security_configuration" "this" {
  name = join("-", ["sdlf", var.team_name, "emr-security-config"])

  configuration = <<EOF
{
  "EncryptionConfiguration": {
    "EnableInTransitEncryption" : false,
    "EnableAtRestEncryption" : true,
    "AtRestEncryptionConfiguration" : {
      "S3EncryptionConfiguration" : {
        "EncryptionMode" : "SSE-KMS",
        "AwsKmsKey": "${aws_kms_key.data.key_id}"
      },
      "LocalDiskEncryptionConfiguration" : {
        "EncryptionKeyProviderType" : "AwsKms",
        "AwsKmsKey" : "${aws_kms_key.data.key_id}"
      }
    }
  }
}
EOF
}

resource "aws_ssm_parameter" "infra_key" {
  name        = join("/", ["/SDLF/KMS", var.team_name, "InfraKeyId"])
  type        = "String"
  value       = aws_kms_key.infra.arn
  description = join("", ["Arn of the ", var.team_name, " KMS infrastructure key"])
}

resource "aws_ssm_parameter" "data_key" {
  name        = join("/", ["/SDLF/KMS", var.team_name, "DataKeyId"])
  type        = "String"
  value       = aws_kms_key.data.arn
  description = join("", ["Arn of the ", var.team_name, " KMS data key"])
}
