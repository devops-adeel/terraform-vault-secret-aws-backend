locals {
  application_name = "terraform-modules-development-aws"
  env              = "dev"
  service          = "web"
}

resource "vault_namespace" "default" {
  path = local.application_name
}

provider "vault" {
  alias     = "default"
  namespace = trimsuffix(vault_namespace.default.id, "/")
}

module "default" {
  source = "./module"
  providers = {
    vault = vault.default
  }
  group_ids = [module.vault_approle.group_id]
}

module "vault_approle" {
  source = "git::https://github.com/devops-adeel/terraform-vault-approle.git?ref=v0.4.1"
  providers = {
    vault = vault.default
  }
  application_name = local.application_name
  env              = local.env
  service          = local.service
}

data "aws_iam_policy_document" "default" {
  version = "2012-10-17"
  statement {
    actions = [
      "iam:*",
    ]
    resources = [
      "*"
    ]
  }
}

resource "vault_aws_secret_backend_role" "default" {
  provider = vault.default
  backend  = module.default.backend_path
  name     = format("%s-%s", local.env, local.service)
  policy   = data.aws_iam_policy_document.default.json
}

provider "vault" {
  alias     = "aws"
  namespace = trimsuffix(vault_namespace.default.id, "/")

  auth_login {
    path = "auth/approle/login"

    parameters = {
      role_id   = module.vault_approle.approle_id
      secret_id = module.vault_approle.approle_secret
    }
  }
}

data "vault_aws_access_credentials" "default" {
  provider = vault.aws
  backend  = module.default.backend_path
  role     = vault_aws_secret_backend_role.default.name
}

provider "aws" {
  access_key = data.vault_aws_access_credentials.default.access_key
  secret_key = data.vault_aws_access_credentials.default.secret_key
}

resource "aws_iam_user" "default" {
  name = local.application_name
}
