resource "vault_aws_secret_backend" "default" {}

data "vault_policy_document" "default" {
  rule {
    path         = "aws/creds/{{identity.entity.metadata.env}}-{{identity.entity.metadata.service}}"
    capabilities = ["read"]
    description  = "Allow generating credentials"
  }
}

resource "vault_policy" "default" {
  name   = "aws-creds"
  policy = data.vault_policy_document.default.hcl
}

resource "vault_identity_group" "default" {
  name              = "aws-creds"
  type              = "internal"
  policies          = ["default", vault_policy.default.name]
  member_entity_ids = var.entity_ids != [] ? var.entity_ids : [vault_identity_entity.default.id]
}

resource "vault_identity_entity" "default" {
  name = "default"
}
