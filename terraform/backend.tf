terraform {
  backend "s3" {
    region = "us-west-2"
    bucket = "weavegrid-tf-state"
    key    = "vsp/tesla-http-proxy-deploy/terraform.tfstate"
  }
}
