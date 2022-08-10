# sdlf-pipeline

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| pipeline-a | ./modules/stage-a |  |
| pipeline-b | ./modules/stage-b |  |

## Resources

| Name |
|------|
| [aws_lambda_layer_version](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lambda_layer_version) |
| [aws_ssm_parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| analytics\_bucket | The analytics bucket for the solution | `any` | `null` | no |
| application\_name | Name of the application | `any` | `null` | no |
| artifacts\_bucket | The artifacts bucket for the solution | `any` | `null` | no |
| central\_bucket | The central bucket for the solution | `any` | `null` | no |
| cfn\_bucket | The artifactory bucket used by CodeBuild and CodePipeline | `any` | `null` | no |
| elasticsearch\_enabled | Boolean for wether ElasticSearch is enabled | `bool` | `false` | no |
| environment | Environment name | `any` | `null` | no |
| kibana\_function\_arn | specify arn of elasticsearch collation lambda if elasticsearch is enable and not using the default | `any` | `null` | no |
| organization | Name of the organization owning the datalake | `any` | `null` | no |
| pipeline\_name | The name of the pipeline (all lowercase, no symbols or spaces) | `any` | n/a | yes |
| raw\_bucket | n/a | `any` | `null` | no |
| shared\_devops\_account\_id | Shared DevOps Account Id | `any` | `null` | no |
| stageA\_branch | The branch containing feature releases for the StageA Machine. If unique across all pipelines, then git push will only trigger the specific pipeline's CodePipeline. Defaults to master. | `string` | `"master"` | no |
| stageA\_statemachine\_repository | The name of the repository containing the code for StageA's State Machine. | `string` | `"stageA"` | no |
| stageB\_branch | The branch containing feature releases for the StageB Machine. If unique across all pipelines, then git push will only trigger the specific pipeline's CodePipeline. Defaults to master. | `string` | `"master"` | no |
| stageB\_statemachine\_repository | The name of the repository containing the code for StageB's State Machine. | `string` | `"stageB"` | no |
| stage\_bucket | The stage bucket for the solution | `any` | `null` | no |
| states\_execution\_role\_arn | role for pipelines (statemachines) to use | `any` | `null` | no |
| team\_name | Name of the team owning the pipeline (all lowercase, no symbols or spaces) | `any` | n/a | yes |

## Outputs

No output.
