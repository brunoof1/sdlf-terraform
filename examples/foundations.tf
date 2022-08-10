
# sdlf-foundations
module "foundations" {
  source                            = "./modules/sdlf-foundations"
  application_name                  = "sdlf"
  environment                       = "dev"
  number_of_buckets                 = 3
  organization_name                 = "hansonlu"
  sns_notifications_email           = "hansonlu@amazon.com"
  enforce_bucket_owner_full_control = true
  cross_account_principals = [
    "arn:aws:iam::224347743947:root"
  ]
  lakeformation_admin_principals = [
    "arn:aws:iam::508781790951:user/salo"
  ]
}
