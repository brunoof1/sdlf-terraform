# sdlf-dataset

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Modules

No Modules.

## Resources

| Name |
|------|
| [aws_caller_identity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) |
| [aws_cloudwatch_event_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) |
| [aws_cloudwatch_event_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) |
| [aws_dynamodb_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/dynamodb_table) |
| [aws_dynamodb_table_item](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item) |
| [aws_glue_catalog_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_catalog_database) |
| [aws_glue_crawler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_crawler) |
| [aws_lakeformation_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) |
| [aws_lambda_permission](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) |
| [aws_region](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) |
| [aws_sqs_queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) |
| [aws_ssm_parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) |
| [aws_ssm_parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| analytics\_bucket | The analytics bucket for the solution | `any` | `null` | no |
| application\_name | Name of the application | `any` | `null` | no |
| central\_bucket | The central bucket for the solution | `any` | `null` | no |
| dataset\_name | The name of the dataset (all lowercase, no symbols or spaces | `any` | n/a | yes |
| environment | Environment name | `any` | `null` | no |
| organization | Name of the organization owning the datalake | `any` | `null` | no |
| pipeline\_bucket | The artifactory bucket used by CodeBuild and CodePipeline | `any` | `null` | no |
| pipeline\_name | The name of the pipeline (all lowercase, no symbols or spaces) | `any` | n/a | yes |
| stage\_a\_transform\_name | n/a | `string` | `"light_transform_blueprint"` | no |
| stage\_b\_transform\_name | n/a | `string` | `"heavy_transform_blueprint"` | no |
| stage\_bucket | The stage bucket for the solution | `any` | `null` | no |
| team\_name | Name of the team owning the pipeline (all lowercase, no symbols or spaces) | `any` | n/a | yes |

## Outputs

No output.
