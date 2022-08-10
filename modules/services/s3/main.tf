
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}


resource "aws_s3_bucket_acl" "log_bucket" {
  count  = var.bucket_acl == null ? 0 : 1
  bucket = aws_s3_bucket.this.id
  acl    = var.bucket_acl
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.sse_algorithm
    }
  }
}

resource "aws_s3_bucket_logging" "this" {
  count         = var.s3_access_logs_bucket == null ? 0 : 1
  bucket        = aws_s3_bucket.this.id
  target_bucket = var.s3_access_logs_bucket
  target_prefix = var.s3_access_logs_target_prefix
}

resource "aws_s3_bucket_versioning" "this" {
  count  = var.enable_bucket_versioning ? 1 : 0
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count                   = var.block_public_access ? 1 : 0
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_lakeformation_resource" "central" {
  count = var.enable_lakeformation ? 1 : 0
  arn   = aws_s3_bucket.this.arn
}