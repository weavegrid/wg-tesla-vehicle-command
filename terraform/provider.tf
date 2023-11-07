provider "aws" {
  region = "us-west-2"
  assume_role {
    role_arn     = "arn:aws:iam::243128163639:role/OrganizationAccountAccessRole"
    session_name = "vsp-cicd"
    external_id  = "vsp-cicd"
  }
}

provider "aws" {
  alias = "peer"
  region = "us-west-2"
}
