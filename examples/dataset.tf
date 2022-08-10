# sdlf dataset
module "example-dataset" {
  source        = "./modules/sdlf-dataset"
  team_name     = "engineering"
  pipeline_name = "main"
  dataset_name  = "legislators"
}
