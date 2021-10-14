terraform {
  backend "s3" {
    bucket  = "greyhats13-tfstate"
    region  = "ap-southeast-1"
    key     = "lapak-toolchain-jenkins-agent-role-binding-dev.tfstate"
    profile = "lapak-dev"
  }
}

module "k8s" {
  source   = "../../modules/k8s"
  region   = "sgp1"
  env      = "dev"
  unit     = "lapak"
  code     = "toolchain"
  feature  = "jenkins-agent-role-binding"
  manifest = file("service-account.yaml")
}
