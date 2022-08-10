# generic example
module "example-dataset-job" {
  source             = "./modules/sdlf-dataset-job"
  dataset_name       = "legislators"
  team_name          = "engineering"
  upload_sample_data = true
}

# example with your own glue script
module "custom-dataset-job" {
  source           = "./modules/sdlf-dataset-job"
  dataset_name     = "legislators"
  team_name        = "engineering"
  glue_script_path = "scripts/my-custom-glue-job.py" # this must exist relative to your working directory on the local filesystem
}
