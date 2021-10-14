terraform {
  backend "s3" {
    bucket  = "greyhats13-tfstate"
    region  = "ap-southeast-1"
    key     = "lapak-toolchain-cluster-issuer.tfstate"
    profile = "lapak-dev"
  }
}

module "k8s" {
  source   = "../../modules/k8s"
  region   = "sgp1"
  env      = "dev"
  unit     = "lapak"
  code     = "toolchain"
  feature  = "cluster-issuer"
  manifest = file("cluster-issuer.yaml")
}
