# sdlf-dataset-job

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Modules

No Modules.

## Resources

| Name |
|------|
| [aws_glue_job](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_job) |
| [aws_iam_policy_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) |
| [aws_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) |
| [aws_iam_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) |
| [aws_iam_role_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) |
| [aws_kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_key) |
| [aws_region](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) |
| [aws_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) |
| [aws_s3_bucket_object](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object) |
| [aws_ssm_parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| artifacts\_bucket | the s3 bucket for storing artifacts; it will default to an SSM Param lookup at '/SDLF/S3/ArtifactsBucket' | `any` | `null` | no |
| dataset\_name | name of the dataset | `any` | n/a | yes |
| glue\_script\_path | the path to the script to upload to s3 for the glue job (local filesystem path) | `any` | `null` | no |
| glue\_script\_s3\_key | the s3 key to upload file as; will default to 'datasets/{dataset\_name}/{filename}' | `any` | `null` | no |
| glue\_version | n/a | `string` | `"2.0"` | no |
| kms\_data\_key\_id | the team data kms key id; it will default to an SSM Param lookup at '/SDLF/KMS/{team\_name}/DataKeyId' | `any` | `null` | no |
| kms\_infra\_key\_id | the team infra kms key id; it will default to an SSM Param lookup at '/SDLF/KMS/{team\_name}/InfraKeyId' | `any` | `null` | no |
| max\_concurrent\_runs | n/a | `number` | `3` | no |
| max\_retries | n/a | `number` | `0` | no |
| number\_of\_workers | n/a | `number` | `10` | no |
| tags | tags to add to aws resources | `map` | `{}` | no |
| team\_name | name of the team the dataset belongs to | `any` | n/a | yes |
| upload\_sample\_data | if this is set to 'true' terraform will update the example legislators dataset to your raw bucket; only use this setting in a generic test example | `bool` | `false` | no |
| worker\_type | n/a | `string` | `"G.1X"` | no |

## Outputs

No output.
