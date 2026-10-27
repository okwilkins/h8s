terraform {
  backend "s3" {
    bucket                      = "h8s-terraform-backend"
    key                         = "h8s/bootstrap/00-talos-factory/terraform.tfstate"
    region                      = "eu-central-003"
    endpoints                   = { s3 = "https://s3.eu-central-003.backblazeb2.com" }
    use_path_style              = true
    use_lockfile                = false
    encrypt                     = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
