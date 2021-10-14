terraform {
  backend "s3" {
    bucket  = "greyhats13-tfstate"
    region  = "ap-southeast-1"
    key     = "lapak-database-mysql.tfstate"
    profile = "lapak-dev"
  }
}

variable "mysql_secrets" {
  type = map(string)
  #value is assign on tfvars
}

module "helm" {
  source     = "../../modules/helm"
  region     = "sgp1"
  env        = "dev"
  unit       = "lapak"
  code       = "database"
  feature    = "mysql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "mysql"
  values     = []
  helm_sets = [
    {
      name  = "auth.rootPassword"
      value = var.mysql_secrets["rootPassword"]
    },
    {
      name  = "auth.database"
      value = "contohlapak"
    },
    {
      name  = "primary.persistence.size"
      value = "2Gi"
    },
    {
      name  = "secondary.persistence.size"
      value = "2Gi"
    },
    {
      name  = "primary.nodeSelector.service"
      value = "backend"
    },
    {
      name  = "secondary.nodeSelector.service"
      value = "backend"
    }
  ]
  override_namespace = "database"
  no_env             = true
}