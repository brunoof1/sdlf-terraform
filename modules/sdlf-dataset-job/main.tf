data "aws_region" "current" {}

resource "aws_iam_role" "this" {
  name               = "sdlf-${var.team_name}-${var.dataset_name}-glue-job"
  path               = "/"
  tags               = var.tags
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "glue.${data.aws_region.current.name}.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "logs_full_access" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy" "this" {
  name   = "sdlf-${var.team_name}-${var.dataset_name}-glue-job"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}

data "aws_ssm_parameter" "kms_infra_key_id" {
  count = var.kms_infra_key_id == null ? 1 : 0
  name  = "/SDLF/KMS/${var.team_name}/InfraKeyId"
}

data "aws_ssm_parameter" "kms_data_key_id" {
  count = var.kms_data_key_id == null ? 1 : 0
  name  = "/SDLF/KMS/${var.team_name}/DataKeyId"
}

data "aws_kms_key" "infra" {
  key_id = var.kms_infra_key_id == null ? data.aws_ssm_parameter.kms_infra_key_id[0].value : var.kms_infra_key_id
}

data "aws_kms_key" "data" {
  key_id = var.kms_data_key_id == null ? data.aws_ssm_parameter.kms_data_key_id[0].value : var.kms_data_key_id
}

data "aws_iam_policy_document" "this" {
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
      data.aws_kms_key.infra.arn,
      data.aws_kms_key.data.arn
    ]
  }
}

data "aws_ssm_parameter" "artifacts_bucket" {
  count = var.artifacts_bucket == null ? 1 : 0
  name  = "/SDLF/S3/ArtifactsBucket"
}

data "aws_s3_bucket" "artifacts" {
  bucket = var.artifacts_bucket == null ? data.aws_ssm_parameter.artifacts_bucket[0].value : var.artifacts_bucket
}

locals {
  glue_script_path = var.glue_script_path == null ? "${path.module}/example/legislators-glue-job.py" : "${path.root}/${var.glue_script_path}"
}

resource "aws_s3_object" "this" {
  key    = var.glue_script_s3_key == null ? "datasets/${var.dataset_name}/${reverse(split("/", local.glue_script_path))[0]}" : var.glue_script_s3_key
  bucket = data.aws_s3_bucket.artifacts.id
  source = local.glue_script_path
  etag   = filemd5(local.glue_script_path)

}

resource "aws_glue_job" "this" {
  name              = "sdlf-${var.team_name}-${var.dataset_name}-glue-job"
  role_arn          = aws_iam_role.this.arn
  glue_version      = var.glue_version
  max_retries       = var.max_retries
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers

  execution_property {
    max_concurrent_runs = var.max_concurrent_runs
  }

  command {
    name            = "glueetl"
    script_location = join("", ["s3://", data.aws_s3_bucket.artifacts.id, "/", aws_s3_object.this.id])
  }

  default_arguments = {
    "--job-bookmark-option" = "job-bookmark-enable"
    "--enable-metrics"      = "true"
  }

  tags = var.tags
}

# sample data upload
data "aws_ssm_parameter" "raw_bucket" {
  count = var.upload_sample_data == true ? 1 : 0
  name  = "/SDLF/S3/CentralBucket"
}

locals {
  sample_data = [
    "memberships.json",
    "organizations.json",
    "persons.json",
    "regions.json"
  ]
}

resource "aws_s3_object" "sample_data" {
  for_each = var.upload_sample_data == true ? toset(local.sample_data) : toset([])
  key      = join("/", [var.team_name, var.dataset_name, each.value])
  bucket   = data.aws_ssm_parameter.raw_bucket[0].value
  source   = join("/", [path.module, "example/data", each.value])
}
