terraform {
  backend "s3" {
    bucket       = "central-platform-tfstate-2026"
    key          = "envs/prod/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}
