terraform {
  backend "s3" {
    bucket  = "greyhats13-tfstate"
    region  = "ap-southeast-1"
    key     = "lapak-k8s-cluster-dev.tfstate"
    profile = "lapak-dev"
  }
}

#Initial Setup
variable "do_token" {
  #the value is assigned from tfvars
}

module "k8s_cluster" {
  source         = "../../modules/k8s-cluster"
  region         = "sgp1"
  env            = "dev"
  unit           = "lapak"
  code           = "k8s"
  feature        = ["cluster", "pool"]
  do_token       = var.do_token
  version_prefix = "1.21."
  node_type      = "s-2vcpu-4gb"
  auto_scale     = true
  min_nodes      = 5
  max_nodes      = 10
  node_labels = {
    service  = "backend"
    priority = "high"
  }
  node_taint = {}
  namespaces = [ "dev", "stg", "lapak", "ingress", "cicd", "database" ]
}
