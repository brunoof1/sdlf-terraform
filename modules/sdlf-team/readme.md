# sdlf-team

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| cicd | ./modules/cicd |  |
| codecommit_role | ./modules/codecommit-role |  |
| iam | ./modules/iam |  |
| kms | ./modules/kms |  |

## Resources

| Name |
|------|
| [aws_lakeformation_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) |
| [aws_ssm_parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| application\_name | Name of the application | `any` | `null` | no |
| datalake\_library\_lambda\_layer\_name | Name to give the Lambda Layer containing the Datalake Library | `string` | `"datalake-lib-layer"` | no |
| datalake\_library\_repository\_name | Name of the repository containing the code for the Datalake Library. | `string` | `"common-datalakeLibrary"` | no |
| default\_pip\_libraries\_lambda\_layer\_name | Name to give the Lambda Layer containing the libraries installed through Pip | `string` | `"default-pip-libraries"` | no |
| enforce\_code\_coverage | Creates code coverage reports from the unit tests included in `pDatalakeLibraryRepositoryName`. Enforces the minimum threshold specified in `pMinTestCoverage` | `bool` | `false` | no |
| environment | Environment Name | `any` | `null` | no |
| libraries\_branch\_name | Name of the default branch for Python libraries | `string` | `"master"` | no |
| minimum\_test\_coverage | [OPTIONAL] The minimum code coverage percentage that is required for the pipeline to proceed to the next stage. Specify only if `enforce_code_coverage` is set to 'true'. | `number` | `80` | no |
| organization\_name | Name of the organization owning the datalake | `any` | `null` | no |
| pip\_libraries\_repository\_name | The repository containing requirements.txt | `string` | `"common-pipLibrary"` | no |
| shared\_devops\_account\_id | Shared DevOps Account Id | `any` | `null` | no |
| sns\_notifications\_email | Email address for SNS notifications | `string` | `"nobody@amazon.com"` | no |
| team\_name | Name of the team (all lowercase, no symbols or spaces) | `any` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| datalake\_library\_layer\_repo\_clone\_url | n/a |
| pip\_libraries\_repo\_clone\_url | n/a |
