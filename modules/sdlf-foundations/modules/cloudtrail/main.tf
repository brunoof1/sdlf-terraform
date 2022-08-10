# Cloudtrail

# lookups
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# resources
resource "aws_s3_bucket" "cloudtrail" {
  count  = var.external_trail_bucket == null ? 1 : 0
  bucket = var.custom_bucket_prefix == null ? join("-", [var.organization_name, var.application_name, var.environment, data.aws_region.current.name, data.aws_caller_identity.current.account_id, "cloudtrail"]) : join("-", [var.custom_bucket_prefix, "cloudtrail"])
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  count  = var.external_trail_bucket == null ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count                   = var.external_trail_bucket == null ? 1 : 0
  bucket                  = aws_s3_bucket.cloudtrail[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count  = var.external_trail_bucket == null ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id
  policy = data.aws_iam_policy_document.cloudtrail_bucket[0].json
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  count = var.external_trail_bucket == null ? 1 : 0

  statement {
    sid = "AWSCloudTrailAclCheck"
    actions = [
      "s3:GetBucketAcl"
    ]
    resources = [
      aws_s3_bucket.cloudtrail[0].arn
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid = "AWSCloudTrailWrite"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      var.log_file_prefix != null ? join("/", [aws_s3_bucket.cloudtrail[0].arn, var.log_file_prefix, "AWSLogs", data.aws_caller_identity.current.account_id, "*"]) : join("/", [aws_s3_bucket.cloudtrail[0].arn, "AWSLogs", data.aws_caller_identity.current.account_id, "*"])
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = var.cloudtrail_name == null ? join("-", [var.environment, var.application_name]) : var.cloudtrail_name
  retention_in_days = var.cloudwatch_logs_retention
}

resource "aws_iam_role" "cloudtrail" {
  name_prefix = "cloudtrail-"
  path        = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "cloudtrail.amazonaws.com"
            },
            "Effect": "Allow"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "cloudtrail" {
  role   = aws_iam_role.cloudtrail.name
  policy = data.aws_iam_policy_document.cloudtrail_role.json
}

data "aws_iam_policy_document" "cloudtrail_role" {
  policy_id = "cloudtrail-policy"

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    resources = [
      join("", [aws_cloudwatch_log_group.cloudtrail.arn, ":*"])
    ]
  }
}


resource "aws_cloudtrail" "this" {
  name                          = var.cloudtrail_name == null ? join("-", [var.environment, var.application_name]) : var.cloudtrail_name
  include_global_service_events = true
  enable_logging                = true
  is_multi_region_trail         = false
  kms_key_id                    = var.kms_key_arn
  s3_bucket_name                = var.external_trail_bucket == null ? aws_s3_bucket.cloudtrail[0].id : var.external_trail_bucket
  s3_key_prefix                 = var.log_file_prefix
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = join("", [aws_cloudwatch_log_group.cloudtrail.arn, ":*"])
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail.arn

  dynamic "event_selector" {
    for_each = var.s3_data_events == true ? [1] : []

    content {
      read_write_type           = "All"
      include_management_events = true

      data_resource {
        type   = "AWS::S3::Object"
        values = ["arn:aws:s3:::"]
      }
    }
  }

  depends_on = [aws_cloudwatch_log_group.cloudtrail]
}

resource "aws_ssm_parameter" "cloudtrail_bucket" {
  name        = "/SDLF/S3/CloudTrailBucket"
  type        = "String"
  value       = var.external_trail_bucket == null ? aws_s3_bucket.cloudtrail[0].id : var.external_trail_bucket
  description = "Name of the Cloudtrail S3 bucket"
}
