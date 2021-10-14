terraform {
  backend "s3" {
    bucket  = "greyhats13-tfstate"
    region  = "ap-southeast-1"
    key     = "lapak-vpc-network-dev.tfstate"
    profile = "lapak-dev"
  }
}

module "vpc" {
  source   = "../../modules/vpc"
  region   = "sgp1"
  env      = "dev"
  unit     = "lapak"
  code     = "vpc"
  feature  = "network"
  ip_range = "10.0.0.0/16"
}
