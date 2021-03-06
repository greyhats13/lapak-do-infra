terraform {
  backend "s3" {
    bucket  = "greyhats13-tfstate"
    region  = "ap-southeast-1"
    key     = "lapak-database-redis.tfstate"
    profile = "lapak-dev"
  }
}

variable "redis_secrets" {
  type = map(string)
  #value is assign on tfvars
  sensitive = true
}

module "helm" {
  source     = "../../modules/helm"
  region     = "sgp1"
  env        = "dev"
  unit       = "lapak"
  code       = "database"
  feature    = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  values     = []
  helm_sets = [
    # {
    #   name  = "auth.rootPassword"
    #   value = var.redis_secrets["redisPassword"]
    # },
    {
      name  = "auth.enabled"
      value = false
    },
    {
      name  = "replica.replicaCount"
      value = "1"
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
      name  = "master.nodeSelector.service"
      value = "backend"
    },
    {
      name  = "replica.nodeSelector.service"
      value = "backend"
    }
  ]
  override_namespace = "database"
  no_env             = true
}