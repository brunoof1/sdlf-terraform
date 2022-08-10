provider "aws" {
  region = "us-west-2"
}

terraform {
  backend "s3" {
    bucket = "clevertime-terraform-aws-sdlf-state"
    key    = "clevertime-sdlf"
    region = "us-west-2"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# sdlf common
module "foundations" {
  source                  = "./modules/sdlf-foundations"
  application_name        = "sdlf"
  environment             = "dev"
  number_of_buckets       = 3
  organization_name       = "hansonlu"
  sns_notifications_email = "hansonlu@amazon.com"
  lakeformation_admin_principals = [
    # this should match the credentials you are using to run terraform to deploy team/pipeline/dataset modules below
    "arn:aws:iam::508781790951:role/GitLab",
    "arn:aws:iam::508781790951:role/admin"
  ]
}

# sdlf team
module "example-team" {
  source                   = "./modules/sdlf-team"
  team_name                = "engineering"
  shared_devops_account_id = data.aws_caller_identity.current.account_id
}

# sdlf pipeline
module "example-pipeline" {
  source        = "./modules/sdlf-pipeline"
  team_name     = "engineering"
  pipeline_name = "main"
}

# sdlf dataset
module "example-dataset" {
  source        = "./modules/sdlf-dataset"
  team_name     = "engineering"
  pipeline_name = "main"
  dataset_name  = "legislators"
}

# generic example
module "example-dataset-job" {
  source             = "./modules/sdlf-dataset-job"
  dataset_name       = "legislators"
  team_name          = "engineering"
  upload_sample_data = true
}

output "ingestion_bucket" {
  value = module.foundations.ingestion_bucket
}
