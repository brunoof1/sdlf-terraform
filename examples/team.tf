# sdlf team
module "example-team" {
  source                   = "./modules/sdlf-team"
  team_name                = "engineering"
  shared_devops_account_id = data.aws_caller_identity.current.account_id
}
