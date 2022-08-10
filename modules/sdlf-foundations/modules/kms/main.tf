# lookups
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# kms key
resource "aws_kms_key" "this" {
  description         = var.description
  enable_key_rotation = var.enable_key_rotation
  policy              = var.key_policy == null ? data.aws_iam_policy_document.this.0.json : var.key_policy
}

# kms key policy
data "aws_iam_policy_document" "this" {
  count = var.key_policy == null ? 1 : 0

  statement {
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
}

# kms alias
resource "aws_kms_alias" "this" {
  name          = var.alias
  target_key_id = aws_kms_key.this.key_id
}
