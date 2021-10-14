terraform {
  backend "s3" {
    bucket  = "greyhats13-tfstate"
    region  = "ap-southeast-1"
    key     = "lapak-project-dev.tfstate"
    profile = "lapak-dev"
  }
}

module "project" {
  source       = "../../modules/project"
  region       = "sgp1"
  env          = "dev"
  unit         = "lapak"
  code         = "do"
  feature      = "infra"
  project_name = "Bukalapak"
  purpose      = "Service or API"
}
