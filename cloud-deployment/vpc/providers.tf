#Initial Setup
variable "do_token" {
  #the value is assigned on tfvars
}

provider "digitalocean" {
  token = var.do_token
}