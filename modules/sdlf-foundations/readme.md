# sdlf-foundations
shared datalake infrastructure

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| cloudtrail | ./modules/cloudtrail |  |
| dynamo | ./modules/dynamo |  |
| glue | ./modules/glue |  |
| kibana | ./modules/kibana |  |
| kms | ./modules/kms |  |
| s3 | ./modules/s3 |  |

## Resources

| Name |
|------|
| [aws_caller_identity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) |
| [aws_iam_policy_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) |
| [aws_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) |
| [aws_iam_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) |
| [aws_iam_role_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) |
| [aws_lakeformation_data_lake_settings](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_data_lake_settings) |
| [aws_region](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) |
| [aws_ssm_parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| application\_name | Name of the application (all lowercase, no symbols or spaces) | `string` | `"datalake"` | no |
| cloudtrail\_enabled | To Deploy CloudTrail, set this to true | `bool` | `false` | no |
| cognito\_admin\_email | Email address of the Cognito admin | `string` | `"nobody@amazon.com"` | no |
| cross\_account\_principals | list of aws account principals to allow writing to sdlf s3 | `list` | `[]` | no |
| custom\_bucket\_prefix | S3 Bucket Prefix if different from default. Must be a valid S3 prefix name | `any` | `null` | no |
| elasticsearch\_domain\_admin\_email | Email address of the Elasticsearch domain admin | `string` | `"nobody@amazon.com"` | no |
| elasticsearch\_enabled | To Deploy Elasticsearch, set this to true | `bool` | `false` | no |
| enforce\_bucket\_owner\_full\_control | enfoce bucket owner full control on s3 buckets | `bool` | `false` | no |
| enforce\_s3\_secure\_transport | enforce secure tranport policies on s3 buckets | `bool` | `true` | no |
| environment | Environment name | `any` | n/a | yes |
| lakeformation\_admin\_principals | list of iam prinicpals to add as lakeformation principals | `list` | `[]` | no |
| number\_of\_buckets | Number of data lake buckets (3 or 1) | `number` | `3` | no |
| organization\_name | Name of the organization (all lowercase, no symbols or spaces) | `any` | n/a | yes |
| shared\_devops\_account\_id | Shared DevOps Account Id | `any` | `null` | no |
| sns\_notifications\_email | Email address for SNS notifications | `string` | `"nobody@amazon.com"` | no |

## Outputs

| Name | Description |
|------|-------------|
| ingestion\_bucket | Data Lake Ingestion Bucket |
