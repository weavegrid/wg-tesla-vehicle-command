data "terraform_remote_state" "secrets_proxy" {
  backend = "s3"
  config = {
    region = var.aws_region
    bucket = "wg-terragrunt"
    key    = "vsp/secrets-proxy/terraform.tfstate"
  }
}
