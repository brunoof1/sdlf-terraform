output "glue_security_configuration" {
  description = "Glue Security Configuration"
  value       = aws_glue_security_configuration.this.id
}

output "infra_key_arn" {
  description = "Arn of the KMS infrastructure key"
  value       = aws_kms_key.infra.arn
}

output "infra_key_id" {
  description = "Id of the KMS infrastructure key"
  value       = aws_kms_key.infra.id
}

output "data_key_arn" {
  description = "Arn of the KMS data key"
  value       = aws_kms_key.data.arn
}

output "data_key_id" {
  description = "Id of the KMS data key"
  value       = aws_kms_key.data.id
}
