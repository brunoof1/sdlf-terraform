# Dynamo Module: "DynamoDB Resources to be created by the common stack"

resource "aws_dynamodb_table" "metadata" {
  name             = join("-", ["octagon-ObjectMetadata", var.environment])
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "id"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}

resource "aws_dynamodb_table" "datasets" {
  name         = join("-", ["octagon-Datasets", var.environment])
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "name"

  attribute {
    name = "name"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}

resource "aws_dynamodb_table" "artifacts" {
  name         = join("-", ["octagon-Artifacts", var.environment])
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "date"
    type = "S"
  }

  attribute {
    name = "pipeline_and_target_type"
    type = "S"
  }

  attribute {
    name = "dataset"
    type = "S"
  }

  attribute {
    name = "pipeline"
    type = "S"
  }

  attribute {
    name = "pipelineSessionId"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  global_secondary_index {
    name            = "date-pipeline-artifact-type-index"
    hash_key        = "date"
    range_key       = "pipeline_and_target_type"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "dataset-date-index"
    hash_key        = "dataset"
    range_key       = "date"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "date-dataset-index"
    hash_key        = "date"
    range_key       = "dataset"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "pipeline-date-index"
    hash_key        = "pipeline"
    range_key       = "date"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "pipelineSessionId-index"
    hash_key        = "pipelineSessionId"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}

resource "aws_dynamodb_table" "metrics" {
  name         = join("-", ["octagon-Metrics", var.environment])
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "root"
  range_key    = "metric"

  attribute {
    name = "root"
    type = "S"
  }

  attribute {
    name = "metric"
    type = "S"
  }

  attribute {
    name = "last_updated_date"
    type = "S"
  }

  attribute {
    name = "type"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  global_secondary_index {
    name            = "last_updated_date-metric-index"
    hash_key        = "last_updated_date"
    range_key       = "metric"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "type-metric-index"
    hash_key        = "type"
    range_key       = "metric"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "root-last_updated_date-index"
    hash_key        = "root"
    range_key       = "last_updated_date"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}

resource "aws_dynamodb_table" "configuration" {
  name         = join("-", ["octagon-Configuration", var.environment])
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "key"

  attribute {
    name = "key"
    type = "S"
  }

  attribute {
    name = "type"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  global_secondary_index {
    name            = "type-index"
    hash_key        = "type"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}

resource "aws_dynamodb_table" "pipelines" {
  name         = join("-", ["octagon-Pipelines", var.environment])
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "name"

  attribute {
    name = "name"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}


resource "aws_dynamodb_table" "events" {
  name         = join("-", ["octagon-Events", var.environment])
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "date"
    type = "S"
  }

  attribute {
    name = "reason"
    type = "S"
  }

  attribute {
    name = "pipeline"
    type = "S"
  }

  attribute {
    name = "date_and_reason"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  global_secondary_index {
    name            = "date-reason-index"
    hash_key        = "date"
    range_key       = "reason"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "pipeline-date_reason-index"
    hash_key        = "pipeline"
    range_key       = "date_and_reason"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "reason-date-index"
    hash_key        = "reason"
    range_key       = "date"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}

resource "aws_dynamodb_table" "execution_history" {
  name         = join("-", ["octagon-PipelineExecutionHistory", var.environment])
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "pipeline"
    type = "S"
  }

  attribute {
    name = "last_updated_timestamp"
    type = "S"
  }

  attribute {
    name = "execution_date"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "status_last_updated_timestamp"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  global_secondary_index {
    name            = "pipeline-last-updated-index"
    hash_key        = "pipeline"
    range_key       = "last_updated_timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "execution_date-status-index"
    hash_key        = "execution_date"
    range_key       = "status"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "pipeline-execution_date-index"
    hash_key        = "pipeline"
    range_key       = "execution_date"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "execution_date-last_updated-index"
    hash_key        = "execution_date"
    range_key       = "last_updated_timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "status-last_updated-index"
    hash_key        = "status"
    range_key       = "last_updated_timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "pipeline-status_last_updated-index"
    hash_key        = "pipeline"
    range_key       = "status_last_updated_timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}

resource "aws_dynamodb_table" "schemas" {
  name             = join("-", ["octagon-DataSchemas", var.environment])
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "name"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "name"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}

resource "aws_dynamodb_table" "quality_suggestions" {
  name         = join("-", ["octagon-DataQualitySuggestions", var.environment])
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "suggestion_hash_key"

  attribute {
    name = "suggestion_hash_key"
    type = "S"
  }

  attribute {
    name = "table_hash_key"
    type = "S"
  }

  global_secondary_index {
    name            = "table-index"
    hash_key        = "table_hash_key"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}

resource "aws_dynamodb_table" "quality_analysis" {
  name         = join("-", ["octagon-DataQualityAnalysis", var.environment])
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "analysis_hash_key"

  attribute {
    name = "analysis_hash_key"
    type = "S"
  }

  attribute {
    name = "table_hash_key"
    type = "S"
  }

  global_secondary_index {
    name            = "table-index"
    hash_key        = "table_hash_key"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}

resource "aws_ssm_parameter" "metadata_table" {
  name        = "/SDLF/Dynamo/ObjectCatalog"
  type        = "String"
  value       = aws_dynamodb_table.metadata.id
  description = "Name of the DynamoDB used to store metadata"
}

resource "aws_ssm_parameter" "mappings_table" {
  name        = "/SDLF/Dynamo/TransformMapping"
  type        = "String"
  value       = aws_dynamodb_table.datasets.id
  description = "Name of the DynamoDB used to store mappings to transformation"
}
