output "object_metadata_stream_arn" {
  value       = aws_dynamodb_table.metadata.stream_arn
  description = "Stream Arn of the ObjectMetadata DynamoDB table"
}

output "schemas_stream_arn" {
  value       = aws_dynamodb_table.schemas.stream_arn
  description = "Stream Arn of the DataSchemas DynamoDB table"
}
